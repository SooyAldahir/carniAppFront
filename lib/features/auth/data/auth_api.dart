import '../../../core/network/api_client.dart';
import 'auth_models.dart';

/// Llamadas HTTP de autenticacion (RF-AUTH-001/002/005).
class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  Future<AuthTokens> login(String nombreUsuario, String password) async {
    final json = await _client.postJson('/api/auth/login', {
      'nombreUsuario': nombreUsuario,
      'password': password,
    });
    return AuthTokens.fromJson(json);
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final json = await _client.postJson('/api/auth/refresh', {
      'refreshToken': refreshToken,
    });
    return AuthTokens.fromJson(json);
  }

  Future<AuthTokens> bootstrapAdmin({
    required String nombreCompleto,
    required String nombreUsuario,
    String? correo,
    required String password,
  }) async {
    final json = await _client.postJson('/api/auth/bootstrap-admin', {
      'nombreCompleto': nombreCompleto,
      'nombreUsuario': nombreUsuario,
      'correo': correo,
      'password': password,
    });
    return AuthTokens.fromJson(json);
  }

  Future<void> logout(String refreshToken) async {
    await _client.postNoContent('/api/auth/logout', {
      'refreshToken': refreshToken,
    });
  }
}
