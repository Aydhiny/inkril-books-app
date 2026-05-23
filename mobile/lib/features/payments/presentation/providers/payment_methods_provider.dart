import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../../core/api/api_client.dart';

// ── Saved payment methods ──────────────────────────────────────────────────

/// Fetches the list of saved card-type PaymentMethods from the backend.
/// Each item is a map: {id, brand, last4, expMonth, expYear}.
final paymentMethodsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio  = ref.read(dioProvider);
  final res  = await dio.get('/api/payments/payment-methods');
  final list = res.data as List? ?? [];
  return list.cast<Map<String, dynamic>>();
});

// ── Setup intent notifier ─────────────────────────────────────────────────

enum SetupStatus { idle, loading, success, failure }

class SetupState {
  final SetupStatus status;
  final String? errorMessage;
  const SetupState({this.status = SetupStatus.idle, this.errorMessage});

  SetupState copyWith({SetupStatus? status, String? errorMessage}) =>
      SetupState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class SetupNotifier extends StateNotifier<SetupState> {
  final _dio;
  final Ref _ref;

  SetupNotifier(this._dio, this._ref) : super(const SetupState());

  /// Presents Stripe's Payment Sheet in setup mode so the user can save a card
  /// without being charged. Returns true on success.
  Future<bool> addCard() async {
    state = state.copyWith(status: SetupStatus.loading, errorMessage: null);

    try {
      // ① Ask backend for a SetupIntent + EphemeralKey
      final res  = await _dio.post('/api/payments/setup-intent');
      final data = res.data as Map<String, dynamic>;

      final setupClientSecret = data['setupIntentClientSecret'] as String;
      final customerId        = data['stripeCustomerId']         as String;
      final ephemeralKey      = data['ephemeralKeySecret']       as String;

      // ② Initialise Payment Sheet in setup mode
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupClientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          merchantDisplayName: 'Inkril Books',
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
            email: CollectionMode.automatic,
          ),
        ),
      );

      // ③ Present the sheet — throws StripeException on cancel/failure
      await Stripe.instance.presentPaymentSheet();

      // Refresh the saved-cards list immediately
      _ref.invalidate(paymentMethodsProvider);

      state = state.copyWith(status: SetupStatus.success);
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        state = state.copyWith(status: SetupStatus.idle);
        return false;
      }
      state = state.copyWith(
        status: SetupStatus.failure,
        errorMessage: e.error.localizedMessage ?? 'Failed to add card.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: SetupStatus.failure,
        errorMessage: 'An unexpected error occurred.',
      );
      return false;
    }
  }

  void reset() => state = const SetupState();
}

final setupProvider =
    StateNotifierProvider.autoDispose<SetupNotifier, SetupState>((ref) {
  return SetupNotifier(ref.read(dioProvider), ref);
});
