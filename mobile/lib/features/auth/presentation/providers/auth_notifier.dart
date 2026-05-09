import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../data/repositories/auth_repository.dart';

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider), ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AsyncData(null));

  Future<void> login(String userNameOrEmail, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.login(userNameOrEmail, password),
    );
    if (!state.hasError) {
      _ref.read(isAuthenticatedProvider.notifier).state = true;
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String userName,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        userName: userName,
        password: password,
      ),
    );
    if (!state.hasError) {
      _ref.read(isAuthenticatedProvider.notifier).state = true;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _ref.read(isAuthenticatedProvider.notifier).state = false;
    state = const AsyncData(null);
  }
}
