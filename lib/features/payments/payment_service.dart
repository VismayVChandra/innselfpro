import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Thin wrapper around the Razorpay checkout SDK. Success here only means
/// the checkout flow completed on-device -- the payments row is only ever
/// marked "paid" by the razorpay-webhook Edge Function after Razorpay's
/// server confirms the capture.
class PaymentService {
  final Razorpay _razorpay = Razorpay();
  void Function()? _onSuccess;
  void Function(String message)? _onError;

  PaymentService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      _onSuccess?.call();
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      _onError?.call(r.message ?? 'Payment failed');
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
  }

  void open({
    required String keyId,
    required String orderId,
    required int amountInPaise,
    required String description,
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) {
    _onSuccess = onSuccess;
    _onError = onError;
    _razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'Innself',
      'description': description,
    });
  }

  void dispose() {
    _razorpay.clear();
  }
}
