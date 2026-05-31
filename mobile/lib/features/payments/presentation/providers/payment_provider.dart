import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../../core/api/api_client.dart';

// ── Purchases provider — caches the list of purchased book IDs ─────────────

/// Provides a Set of book IDs that the current user has successfully purchased.
/// Used by BookDetailScreen to decide between "Buy" and "Read" buttons.
final purchasedBookIdsProvider = FutureProvider<Set<String>>((ref) async {
  final dio = ref.read(dioProvider);
  final res  = await dio.get('/api/payments/my-purchases');
  final list = res.data as List? ?? [];
  return list.map((e) => (e['bookId'] as String)).toSet();
});

// ── Payment state ──────────────────────────────────────────────────────────

enum PaymentStatus { idle, loading, success, failure }

class PaymentState {
  final PaymentStatus status;
  final String? errorMessage;

  const PaymentState({this.status = PaymentStatus.idle, this.errorMessage});

  PaymentState copyWith({PaymentStatus? status, String? errorMessage}) =>
      PaymentState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Payment notifier ───────────────────────────────────────────────────────

class PaymentNotifier extends StateNotifier<PaymentState> {
  final Dio _dio;
  final Ref _ref;

  PaymentNotifier(this._dio, this._ref) : super(const PaymentState());

  /// Full purchase flow for a single premium book:
  /// 1. Create PaymentIntent on backend → get client_secret
  /// 2. Present Stripe Payment Sheet
  /// 3. Confirm purchase on backend → book added to library
  ///
  /// Returns true on success, false on failure or cancellation.
  Future<bool> purchaseBook(String bookId) async {
    state = state.copyWith(status: PaymentStatus.loading, errorMessage: null);

    try {
      // ① Create intent on backend
      final intentRes = await _dio.post(
        '/api/payments/create-intent',
        data: {'bookId': bookId},
      );
      final data             = intentRes.data as Map<String, dynamic>;
      final clientSecret     = data['clientSecret'] as String;
      final paymentIntentId  = data['paymentIntentId'] as String;
      final stripeCustomerId = data['stripeCustomerId'] as String?;
      final ephemeralKey     = data['ephemeralKeySecret'] as String?;

      // ② Initialise the Stripe Payment Sheet.
      // Passing customerId + ephemeralKeySecret makes any saved card appear
      // as a default payment option inside the sheet.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Inkril Books',
          customerId: stripeCustomerId,
          customerEphemeralKeySecret: ephemeralKey,
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
            email: CollectionMode.automatic,
          ),
        ),
      );

      // ③ Present the sheet — throws StripeException on cancel or failure
      await Stripe.instance.presentPaymentSheet();

      // ④ Confirm on backend (verifies with Stripe, marks Purchase succeeded,
      //    adds book to UserBooks so the read-url gate lets the user in)
      await _dio.post(
        '/api/payments/confirm',
        data: {'paymentIntentId': paymentIntentId},
      );

      // Invalidate purchases cache so the UI refreshes immediately
      _ref.invalidate(purchasedBookIdsProvider);

      state = state.copyWith(status: PaymentStatus.success);
      return true;
    } on StripeException catch (e) {
      // User cancelled the sheet — not an error worth showing
      if (e.error.code == FailureCode.Canceled) {
        state = state.copyWith(status: PaymentStatus.idle);
        return false;
      }
      state = state.copyWith(
        status: PaymentStatus.failure,
        errorMessage: e.error.localizedMessage ?? 'Payment failed.',
      );
      return false;
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['detail'] as String?
          ?? e.message
          ?? 'Payment failed.';
      state = state.copyWith(status: PaymentStatus.failure, errorMessage: msg);
      return false;
    } catch (e) {
      // Surface the real error so it can be diagnosed; StripeException and
      // DioException are caught above — anything else here is a PlatformException
      // or an unexpected runtime error (e.g. Stripe SDK initialisation failure).
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        status: PaymentStatus.failure,
        errorMessage: msg.length > 200 ? '${msg.substring(0, 200)}…' : msg,
      );
      return false;
    }
  }

  void reset() => state = const PaymentState();
}

final paymentProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref.read(dioProvider), ref);
});
