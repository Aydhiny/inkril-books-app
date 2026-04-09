class LoginRequest {
  final String userNameOrEmail;
  final String password;
  const LoginRequest({required this.userNameOrEmail, required this.password});
  Map<String, dynamic> toJson() => {
        'userNameOrEmail': userNameOrEmail,
        'password': password,
      };
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String userName;
  final String email;
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.userName,
    required this.email,
  });
  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        userId: j['userId'] as String,
        userName: j['userName'] as String,
        email: j['email'] as String,
      );
}
