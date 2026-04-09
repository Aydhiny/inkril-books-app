import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;
  AuthNotifier(this._repo) : super(const AsyncData(null));

  Future<void> login(String userNameOrEmail, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.login(userNameOrEmail, password),
    );
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
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}
