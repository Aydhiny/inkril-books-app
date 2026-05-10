import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the device has at least one non-none network interface,
/// `false` when every interface reports [ConnectivityResult.none].
///
/// connectivity_plus v6 changed `onConnectivityChanged` to emit
/// `List<ConnectivityResult>` instead of a single value — we map it here
/// so every consumer just deals with a plain bool.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

/// Synchronous snapshot — reads the last-known connectivity state.
/// Defaults to `true` (assume online) until the first event arrives.
/// Prefer this over [connectivityProvider] for simple offline guards.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
    data: (online) => online,
    orElse: () => true,
  );
});
