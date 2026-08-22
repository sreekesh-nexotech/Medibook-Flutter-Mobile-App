import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';

/// Starts the app: ensures the binding, then runs [MedibookApp] inside the
/// root [ProviderScope]. This is the single place to inject global provider
/// overrides (e.g. mock repositories) when the data layer arrives.
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MedibookApp(),
    ),
  );
}
