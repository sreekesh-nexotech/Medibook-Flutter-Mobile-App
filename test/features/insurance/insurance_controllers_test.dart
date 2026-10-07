import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/features/common/attachments/application/providers/attachments_provider.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/common/attachments/domain/repositories/file_url_resolver.dart';
import 'package:medibook/features/common/pagination/domain/entities/paged.dart';
import 'package:medibook/features/insurance/application/providers/insurance_provider.dart';
import 'package:medibook/features/insurance/application/states/insurance_form_state.dart';
import 'package:medibook/features/insurance/application/states/insurance_list_state.dart';
import 'package:medibook/features/insurance/domain/entities/insurance_policy.dart';
import 'package:medibook/features/insurance/domain/repositories/insurance_repository.dart';

/// The insurance list (filters and counts derived from `valid_to`), the add
/// form (validation + the draft it sends) and the per-policy actions
/// (attach / detach / open through the URL resolver) against fakes.
void main() {
  late FakeInsuranceRepository repository;
  late _FakeUrls urls;
  late _Monitor monitor;
  late ProviderContainer container;

  setUp(() {
    repository = FakeInsuranceRepository();
    urls = _FakeUrls();
    monitor = _Monitor();
    container = ProviderContainer(
      overrides: [
        ...appDependencies(),
        insuranceRepositoryProvider.overrideWithValue(repository),
        fileUrlResolverProvider.overrideWithValue(urls),
        connectivityMonitorProvider.overrideWithValue(monitor),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  // BL-INS-006: a saved policy can be edited (the renewal banner asks for
  // the dates to be updated); only what changed is sent, with its version.
  test('editing a policy sends only the changed dates', () async {
    final saved = _policy('pol-1', DateTime(2025, 4, 1), DateTime(2026, 3, 31));
    final controller = InsuranceFormController(
      repository: repository,
      editing: saved,
    );
    addTearDown(controller.dispose);
    expect(controller.state.isDirty, isFalse);

    controller.setValidTo(DateTime(2027, 3, 31));
    expect(controller.state.isDirty, isTrue);
    final updated = await controller.save();

    expect(updated?.validTo, DateTime(2027, 3, 31));
    final (id, patch, version) = repository.updates.single;
    expect(id, 'pol-1');
    expect(version, saved.version);
    expect(patch.validTo, DateTime(2027, 3, 31));
    expect(patch.validFrom, isNull);
    expect(patch.providerName, isNull);
    expect(repository.created, isEmpty);
  });

  group('list', () {
    test('loads, derives the tab counts and orders in-force first', () async {
      final now = DateTime.now();
      repository.policies = [
        _policy(
          'expired',
          now.subtract(const Duration(days: 400)),
          now.subtract(const Duration(days: 30)),
        ),
        _policy(
          'active',
          now.subtract(const Duration(days: 10)),
          now.add(const Duration(days: 300)),
        ),
        _policy(
          'soon',
          now.subtract(const Duration(days: 300)),
          now.add(const Duration(days: 10)),
        ),
      ];
      final sub = container.listen(insuranceListProvider, (_, _) {});
      addTearDown(sub.close);
      expect(container.read(insuranceListProvider).isLoading, isTrue);
      await settle();
      await settle();

      final counts = container.read(insuranceFilterCountsProvider);
      expect(counts[InsuranceFilter.all], 3);
      expect(counts[InsuranceFilter.active], 2);
      expect(counts[InsuranceFilter.expired], 1);
      expect(
        container.read(visibleInsurancePoliciesProvider).map((p) => p.id),
        ['soon', 'active', 'expired'],
      );
      expect(container.read(expiringSoonPoliciesProvider).single.id, 'soon');

      container
          .read(insuranceListProvider.notifier)
          .setFilter(InsuranceFilter.expired);
      expect(
        container.read(visibleInsurancePoliciesProvider).single.id,
        'expired',
      );
    });

    test('a failed load is the error state', () async {
      repository.watchError = const NetworkFailure();
      final sub = container.listen(insuranceListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final state = container.read(insuranceListProvider);
      expect(state.isLoading, isFalse);
      expect(state.failure, isA<NetworkFailure>());
    });

    // Opened offline, the list waits for the network after the saved copy;
    // a pull-to-refresh used to wait until the connection was back.
    test('a pull-to-refresh offline does not wait for the network', () async {
      final now = DateTime.now();
      final network = Completer<void>();
      addTearDown(network.complete);
      repository
        ..policies = [_policy('a', now, now.add(const Duration(days: 300)))]
        ..waitAfterAnswer = network
        ..refreshError = const NetworkFailure();
      final sub = container.listen(insuranceListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();

      await container
          .read(insuranceListProvider.notifier)
          .refresh()
          .timeout(const Duration(seconds: 1));
      final state = container.read(insuranceListProvider);
      expect(state.policies, hasLength(1), reason: 'the saved copy stays');
      expect(state.failure, isA<NetworkFailure>());
    });

    test('a failed read loads again when the network returns', () async {
      final now = DateTime.now();
      repository.watchError = const NetworkFailure();
      final sub = container.listen(insuranceListProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(container.read(insuranceListProvider).failure, isNotNull);

      repository
        ..watchError = null
        ..policies = [_policy('a', now, now.add(const Duration(days: 300)))];
      monitor.reconnect();
      await settle();
      await settle();
      final state = container.read(insuranceListProvider);
      expect(state.failure, isNull);
      expect(state.policies, hasLength(1));
    });
  });

  // Profile's Insurance row shows how many policies are saved, and a
  // pull-to-refresh re-reads it; a failed read never shows a wrong number.
  group('policy count (Profile row)', () {
    test('counts the policies and keeps the last count on failure', () async {
      final now = DateTime.now();
      repository.policies = [
        _policy('a', now, now.add(const Duration(days: 300))),
        _policy('b', now, now.add(const Duration(days: 200))),
      ];
      final sub = container.listen(insurancePolicyCountProvider, (_, _) {});
      addTearDown(sub.close);
      expect(container.read(insurancePolicyCountProvider), isNull);
      await settle();
      expect(container.read(insurancePolicyCountProvider), 2);

      repository.policies = const [];
      await container
          .read(insurancePolicyCountProvider.notifier)
          .refresh(force: true);
      expect(container.read(insurancePolicyCountProvider), 0);

      repository.watchError = const NetworkFailure();
      await container
          .read(insurancePolicyCountProvider.notifier)
          .refresh(force: true);
      expect(container.read(insurancePolicyCountProvider), 0);
    });

    test('is unknown, not zero, when the first read fails', () async {
      repository.watchError = const NetworkFailure();
      final sub = container.listen(insurancePolicyCountProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(container.read(insurancePolicyCountProvider), isNull);
    });

    test('a pull-to-refresh offline does not wait for the network', () async {
      final now = DateTime.now();
      final network = Completer<void>();
      addTearDown(network.complete);
      repository
        ..policies = [_policy('a', now, now.add(const Duration(days: 300)))]
        ..waitAfterAnswer = network
        ..refreshError = const NetworkFailure();
      final sub = container.listen(insurancePolicyCountProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();

      await container
          .read(insurancePolicyCountProvider.notifier)
          .refresh(force: true)
          .timeout(const Duration(seconds: 1));
      expect(container.read(insurancePolicyCountProvider), 1);
    });
  });

  group('form', () {
    test('requires insurer, policy number, holder and both dates', () async {
      final form = container.read(insuranceFormProvider.notifier);
      expect(await form.save(), isNull);
      final errors = container.read(insuranceFormProvider).errors;
      expect(errors.visible(InsuranceField.provider), isNotNull);
      expect(errors.visible(InsuranceField.policyNumber), isNotNull);
      expect(errors.visible(InsuranceField.holderName), isNotNull);
      expect(errors.visible(InsuranceField.validFrom), isNotNull);
      expect(errors.visible(InsuranceField.validTo), isNotNull);
      // Optional on the wire, so no error when empty.
      expect(errors.visible(InsuranceField.planName), isNull);
      expect(errors.visible(InsuranceField.sumInsured), isNull);
      expect(repository.created, isEmpty);
    });

    test('cover cannot end before it starts', () {
      final form = container.read(insuranceFormProvider.notifier);
      form
        ..setValidFrom(DateTime(2026, 4, 1))
        ..setValidTo(DateTime(2026, 3, 1));
      expect(
        container
            .read(insuranceFormProvider)
            .errors
            .visible(InsuranceField.validTo),
        'Cover cannot end before it starts',
      );
    });

    test('a valid form posts integer paise and the person id', () async {
      final form = container.read(insuranceFormProvider.notifier);
      form
        ..setProvider('Star Health')
        ..setPolicyNumber('P/123456/01')
        ..setHolderName('Anita Menon')
        ..setPlanName('Family Optima')
        ..setSumInsuredRupees('500000')
        ..setValidFrom(DateTime(2026, 4, 1))
        ..setValidTo(DateTime(2027, 3, 31))
        ..setPerson('p1')
        ..setNotes('cashless');
      final saved = await form.save();
      expect(saved, isNotNull);
      final draft = repository.created.single;
      expect(draft.sumInsuredPaise, 50000000);
      expect(draft.personId, 'p1');
      expect(draft.notes, 'cashless');
      expect(draft.validTo, DateTime(2027, 3, 31));
    });

    test('server field errors are revealed on the matching field', () async {
      repository.createError = const ValidationFailure(
        fieldErrors: {'valid_to': 'Must be on or after valid_from.'},
      );
      final form = container.read(insuranceFormProvider.notifier);
      form
        ..setProvider('Star Health')
        ..setPolicyNumber('P/123456/01')
        ..setHolderName('Anita Menon')
        ..setValidFrom(DateTime(2026, 4, 1))
        ..setValidTo(DateTime(2027, 3, 31));
      expect(await form.save(), isNull);
      final state = container.read(insuranceFormProvider);
      expect(state.isSaving, isFalse);
      expect(
        state.errors.visible(InsuranceField.validTo),
        contains('valid_from'),
      );
    });
  });

  group('actions', () {
    test('attach and detach go through the repository', () async {
      final actions = container.read(policyActionsProvider('pol').notifier);
      final policy = await actions.attach('pol', 'file-1');
      expect(policy?.documents?.single.fileId, 'file-1');
      expect(repository.attached, [('pol', 'file-1')]);

      final failure = await actions.detach('pol', 'file-1');
      expect(failure, isNull);
      expect(repository.detached, [('pol', 'file-1')]);
      expect(urls.forgotten, ['file-1']);
    });

    test(
      'an attach refused by the server keeps the failure on state',
      () async {
        repository.attachError = const ValidationFailure(
          fieldErrors: {'file_id': 'Must be one of your own insurance files.'},
        );
        final actions = container.read(policyActionsProvider('pol').notifier);
        expect(await actions.attach('pol', 'bad'), isNull);
        expect(
          container.read(policyActionsProvider('pol')).failure,
          isA<ValidationFailure>(),
        );
      },
    );

    test('fileUrl resolves through the shared resolver', () async {
      final actions = container.read(policyActionsProvider('pol').notifier);
      final url = await actions.fileUrl('file-1');
      expect(url?.url, 'https://signed.example/file-1');
    });
  });
}

InsurancePolicy _policy(String id, DateTime from, DateTime to) =>
    InsurancePolicy(
      id: id,
      providerName: 'Star Health',
      policyNumber: 'P/$id',
      holderName: 'Anita',
      validFrom: from,
      validTo: to,
      version: 1,
    );

/// A connectivity monitor whose reconnects the test sends.
class _Monitor extends ConnectivityMonitor {
  final StreamController<void> _reconnects = StreamController<void>.broadcast();

  void reconnect() => _reconnects.add(null);

  @override
  Stream<void> get onReconnect => _reconnects.stream;
}

class FakeInsuranceRepository implements InsuranceRepository {
  List<InsurancePolicy> policies = [];
  Failure? watchError;
  Failure? createError;
  Failure? attachError;
  final List<PolicyDraft> created = [];
  final List<(String, String)> attached = [];
  final List<(String, String)> detached = [];

  @override
  Stream<Snapshot<List<InsurancePolicy>>> watchPolicies({
    String? personId,
    bool forceRefresh = false,
  }) async* {
    if (watchError != null) throw watchError!;
    if (forceRefresh && refreshError != null) throw refreshError!;
    yield Snapshot(value: policies, cachedAt: DateTime.now());
    final network = waitAfterAnswer;
    if (network != null) await network.future;
  }

  /// Holds a read open after its answer until completed — the cache
  /// offline, waiting for the network (HIVE Scenario 3).
  Completer<void>? waitAfterAnswer;

  /// Thrown at once by a forced read (pull-to-refresh) — offline.
  Failure? refreshError;

  @override
  Future<InsurancePolicy> policy(
    String id, {
    bool forceRefresh = false,
  }) async => policies.firstWhere((p) => p.id == id);

  @override
  Future<InsurancePolicy> create(PolicyDraft draft) async {
    if (createError != null) throw createError!;
    created.add(draft);
    return _policy('new', draft.validFrom, draft.validTo);
  }

  final List<(String, PolicyPatch, int)> updates = [];

  @override
  Future<InsurancePolicy> update(
    String id,
    PolicyPatch patch, {
    required int version,
  }) async {
    updates.add((id, patch, version));
    return _policy(id, DateTime(2026), patch.validTo ?? DateTime(2027));
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<InsurancePolicy> attachDocument(String id, String fileId) async {
    if (attachError != null) throw attachError!;
    attached.add((id, fileId));
    return _policy(id, DateTime(2026), DateTime(2027)).copyWith(
      documents: [
        PolicyDocument(
          fileId: fileId,
          originalName: 'policy.pdf',
          mime: 'application/pdf',
          sizeBytes: 10,
          status: FileStatus.clean,
        ),
      ],
    );
  }

  @override
  Future<void> detachDocument(String id, String fileId) async =>
      detached.add((id, fileId));
}

class _FakeUrls implements FileUrlResolver {
  final List<String> forgotten = [];

  @override
  Future<SignedFileUrl> resolve(
    String fileId, {
    bool forceRefresh = false,
  }) async => SignedFileUrl(
    url: 'https://signed.example/$fileId',
    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
  );

  @override
  void forget(String fileId) => forgotten.add(fileId);
}
