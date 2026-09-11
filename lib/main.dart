import 'app/bootstrap/app_bootstrap.dart';

/// Entry point. All start-up work — crash reporting, configuration validation,
/// local storage, portrait lock — lives in [bootstrap], so this file stays a
/// one-liner and the order of operations is documented in one place.
void main() {
  bootstrap();
}
