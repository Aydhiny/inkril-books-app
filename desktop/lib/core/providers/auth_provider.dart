import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

/// Single source of truth for auth state.
/// Initialized from secure storage in main() via ProviderScope override.
/// Updated synchronously by LoginScreen after login.
final isAuthenticatedProvider = StateProvider<bool>((_) => false);
