import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether "Available Services" shows every tile or the first three. Opens
/// expanded, as the design does; `autoDispose` so it resets when Home leaves
/// the tree. Purely visual — the data lives in
/// `application/providers/home_providers.dart`.
final homeServicesExpandedProvider = StateProvider.autoDispose<bool>(
  (ref) => true,
);
