import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/money.dart';
import '../medibook_seed.dart';
import '../models/insurance_policy.dart';

/// Owns the account's insurance policies (CM-37 … CM-39).
///
/// **Why this is a shared store:** the Insurance screens manage the policies,
/// and the payment step reads them so a cashless claim can be offered instead
/// of a card. The policy documents also appear in the Records list, which reads
/// the same ids.
class InsuranceStore extends Notifier<List<InsurancePolicy>> {
  @override
  List<InsurancePolicy> build() => MedibookSeed.insurancePolicies;

  /// Policies in force today — the only ones a claim can be made against.
  List<InsurancePolicy> get active =>
      state.where((p) => p.isActive).toList();

  /// Policies within 30 days of expiry — the CM-39 renewal nudge.
  List<InsurancePolicy> get expiringSoon =>
      state.where((p) => p.isExpiringSoon).toList();

  InsurancePolicy? byId(String id) {
    for (final policy in state) {
      if (policy.id == id) return policy;
    }
    return null;
  }

  /// Add a policy (CM-38). Returns the stored record.
  InsurancePolicy add({
    required String provider,
    required String policyNumber,
    required String holderName,
    required String planName,
    required Money sumInsured,
    required DateTime validFrom,
    required DateTime validTo,
    List<String> documents = const <String>[],
    String? tpaName,
  }) {
    final policy = InsurancePolicy(
      id: 'ins-${DateTime.now().microsecondsSinceEpoch}',
      provider: provider,
      policyNumber: policyNumber,
      holderName: holderName,
      planName: planName,
      sumInsured: sumInsured,
      validFrom: validFrom,
      validTo: validTo,
      documents: documents,
      tpaName: tpaName,
    );
    state = [...state, policy];
    return policy;
  }

  void update(InsurancePolicy policy) {
    state = [
      for (final p in state)
        if (p.id == policy.id) policy else p,
    ];
  }

  /// Attach a document id to a policy (the uploaded policy PDF or e-card).
  void attachDocument(String policyId, String documentId) {
    state = [
      for (final p in state)
        if (p.id == policyId && !p.documents.contains(documentId))
          p.copyWith(documents: [...p.documents, documentId])
        else
          p,
    ];
  }

  /// Remove a policy. Returns false for an unknown id.
  bool remove(String id) {
    if (byId(id) == null) return false;
    state = state.where((p) => p.id != id).toList();
    return true;
  }
}

/// The account's insurance policies. Not autoDispose — Insurance and the
/// payment step both read it.
final insuranceStoreProvider =
    NotifierProvider<InsuranceStore, List<InsurancePolicy>>(
      InsuranceStore.new,
    );

/// Policies in force today — what a cashless-claim option may use.
final activeInsurancePoliciesProvider = Provider<List<InsurancePolicy>>((ref) {
  final policies = ref.watch(insuranceStoreProvider);
  return policies.where((p) => p.isActive).toList();
});

/// One policy by id. autoDispose family.
final insurancePolicyByIdProvider = Provider.autoDispose
    .family<InsurancePolicy?, String>((ref, id) {
      final policies = ref.watch(insuranceStoreProvider);
      for (final policy in policies) {
        if (policy.id == id) return policy;
      }
      return null;
    });
