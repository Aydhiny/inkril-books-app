import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class LoginRequest {
  final String userNameOrEmail;
  final String password;
  const LoginRequest({required this.userNameOrEmail, required this.password});
  factory LoginRequest.fromJson(Map<String, dynamic> j) => _$LoginRequestFromJson(j);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
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
  factory AuthResponse.fromJson(Map<String, dynamic> j) => _$AuthResponseFromJson(j);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}
