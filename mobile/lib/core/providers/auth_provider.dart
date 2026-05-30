import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

/// Single source of truth for auth state.
/// Initialized from secure storage in main() via ProviderScope override.
/// Updated synchronously by AuthNotifier after login / logout.
/// GoRouter listens via _RouterNotifier → refreshListenable.
final isAuthenticatedProvider = StateProvider<bool>((_) => false);

/// The logged-in user's role: "desktop" (admin) or "mobile" (regular user).
/// Defaults to "mobile" — overridden in main() from secure storage.
final userRoleProvider = StateProvider<String>((_) => 'mobile');
