import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

enum AuthStatus { desconocido, autenticando, autenticado, noAutenticado }

/// Estado global de sesion (RF-AUTH-001/002). Guarda el access token en
/// memoria y el refresh token en almacenamiento seguro; al abrir la app
/// intenta renovar la sesion automaticamente con el refresh token
/// guardado, para que el usuario no tenga que loguearse cada vez.
class AuthProvider extends ChangeNotifier {
  final AuthApi _authApi;
  final TokenStorage _tokenStorage;

  AuthProvider({AuthApi? authApi, TokenStorage? tokenStorage})
      : _authApi = authApi ?? AuthApi(ApiClient()),
        _tokenStorage = tokenStorage ?? TokenStorage();

  AuthStatus status = AuthStatus.desconocido;
  String? accessToken;
  UsuarioResumen? usuarioActual;
  String? ultimoError;

  bool get estaAutenticado => status == AuthStatus.autenticado;

  /// Se llama una vez al iniciar la app: si hay un refresh token
  /// guardado de una sesion anterior, intenta renovarlo en silencio.
  Future<void> intentarSesionAutomatica() async {
    status = AuthStatus.autenticando;
    notifyListeners();

    final refreshGuardado = await _tokenStorage.leerRefreshToken();

    if (refreshGuardado == null) {
      status = AuthStatus.noAutenticado;
      notifyListeners();
      return;
    }

    try {
      final tokens = await _authApi.refresh(refreshGuardado);
      await _aplicarTokens(tokens);
    } catch (_) {
      await _tokenStorage.limpiar();
      status = AuthStatus.noAutenticado;
      notifyListeners();
    }
  }

  Future<bool> login(String nombreUsuario, String password) async {
    status = AuthStatus.autenticando;
    ultimoError = null;
    notifyListeners();

    try {
      final tokens = await _authApi.login(nombreUsuario, password);
      await _aplicarTokens(tokens);
      return true;
    } on ApiException catch (e) {
      ultimoError = e.mensaje;
      status = AuthStatus.noAutenticado;
      notifyListeners();
      return false;
    } catch (_) {
      ultimoError = 'No se pudo conectar con el servidor.';
      status = AuthStatus.noAutenticado;
      notifyListeners();
      return false;
    }
  }

  Future<bool> bootstrapAdmin({
    required String nombreCompleto,
    required String nombreUsuario,
    String? correo,
    required String password,
  }) async {
    status = AuthStatus.autenticando;
    ultimoError = null;
    notifyListeners();

    try {
      final tokens = await _authApi.bootstrapAdmin(
        nombreCompleto: nombreCompleto,
        nombreUsuario: nombreUsuario,
        correo: correo,
        password: password,
      );
      await _aplicarTokens(tokens);
      return true;
    } on ApiException catch (e) {
      ultimoError = e.mensaje;
      status = AuthStatus.noAutenticado;
      notifyListeners();
      return false;
    } catch (_) {
      ultimoError = 'No se pudo conectar con el servidor.';
      status = AuthStatus.noAutenticado;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final refreshGuardado = await _tokenStorage.leerRefreshToken();

    if (refreshGuardado != null) {
      try {
        await _authApi.logout(refreshGuardado);
      } catch (_) {
        // Si falla la revocacion en el servidor (sin internet, etc.) de
        // todas formas cerramos la sesion localmente.
      }
    }

    await _tokenStorage.limpiar();
    accessToken = null;
    usuarioActual = null;
    status = AuthStatus.noAutenticado;
    notifyListeners();
  }

  Future<void> _aplicarTokens(AuthTokens tokens) async {
    accessToken = tokens.accessToken;
    usuarioActual = tokens.usuario;
    await _tokenStorage.guardarRefreshToken(tokens.refreshToken);
    status = AuthStatus.autenticado;
    notifyListeners();
  }
}
