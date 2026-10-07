import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/payment/application/providers/payment_providers.dart';
import '../../features/payment/infrastructure/data_sources/remote/payment_api.dart';
import '../../features/payment/infrastructure/data_sources/remote/razorpay_checkout_gateway.dart';
import '../../features/payment/infrastructure/repositories/payment_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/payment: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final paymentApiProvider = Provider<PaymentApi>(
  (ref) => HttpPaymentApi(ref.watch(apiClientProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> paymentDependencies = [
  paymentRepositoryProvider.overrideWith(
    (ref) => PaymentRepositoryImpl(api: ref.watch(paymentApiProvider)),
  ),
  checkoutGatewayProvider.overrideWith((ref) {
    final gateway = RazorpayCheckoutGateway();
    ref.onDispose(gateway.dispose);
    return gateway;
  }),
];
