import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();
  String? userId;
  try {
    userId = await storage.read(key: 'user_id');
  } catch (e) {
    try { await storage.deleteAll(); } catch (_) {}
    userId = null;
  }

  runApp(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWith((ref) => userId != null),
    ],
    child: const InkrilAdminApp(),
  ));
}

class InkrilAdminApp extends ConsumerWidget {
  const InkrilAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Inkril Admin',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
