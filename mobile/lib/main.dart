import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/router/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read storage once at startup so the router guard has the correct
  // initial state before the first frame renders.
  const storage = FlutterSecureStorage();
  final userId = await storage.read(key: 'user_id');

  runApp(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWith((ref) => userId != null),
    ],
    child: const InkrilApp(),
  ));
}

class InkrilApp extends ConsumerWidget {
  const InkrilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Inkril',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
