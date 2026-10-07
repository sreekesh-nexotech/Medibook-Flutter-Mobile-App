import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/common/mutation/application/providers/mutation_notifier.dart';

/// Screen Coverage pass (6 Oct 2026): a save whose controller is disposed
/// while the request runs must still report its failure — it used to come
/// back as null, read as success ("added to your family" while offline).
void main() {
  test('a failure after dispose is still returned', () async {
    final controller = _Controller();
    final gate = Completer<void>();
    final result = controller.apply(() async {
      await gate.future;
      throw const NoConnectionException();
    });
    controller.dispose();
    gate.complete();
    expect(await result, isA<Failure>());
  });

  test('success is null, failure is returned', () async {
    final controller = _Controller();
    expect(await controller.apply(() async {}), isNull);
    expect(
      await controller.apply(() async => throw const NoConnectionException()),
      isA<Failure>(),
    );
    controller.dispose();
  });
}

class _Controller extends MutationNotifier {}
