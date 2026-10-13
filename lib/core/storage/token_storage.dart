import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el refresh token de forma segura en el dispositivo (Keychain
/// en iOS/macOS, Keystore en Android, almacenamiento cifrado en web)
/// para que la sesion sobreviva a cerrar y volver a abrir la app
/// (RF-AUTH-002). El access token NO se persiste: vive solo en memoria
/// (AuthProvider), ya que es de corta duracion y se puede regenerar
/// con el refresh token al abrir la app.
class TokenStorage {
  static const _refreshTokenKey = 'carniapp.refresh_token';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> guardarRefreshToken(String refreshToken) =>
      _storage.write(key: _refreshTokenKey, value: refreshToken);

  Future<String?> leerRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> limpiar() => _storage.delete(key: _refreshTokenKey);
}
