import 'dart:async';
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

  DateTime? _accesoExpiraUtc;
  Timer? _temporizadorRefresh;
  Future<bool>? _refrescando;

  /// Devuelve un access token que aun sirve; si esta por vencer (o ya vencio)
  /// lo renueva con el refresh token antes de devolverlo. Las pantallas de uso
  /// prolongado (POS) lo llaman antes de cada peticion: una caja abierta todo
  /// el dia no puede depender del token de 20 minutos con el que inicio.
  Future<String> obtenerTokenVigente() async {
    final token = accessToken;
    final expira = _accesoExpiraUtc;
    if (token != null &&
        expira != null &&
        expira.difference(DateTime.now().toUtc()) > const Duration(seconds: 30)) {
      return token;
    }

    final renovado = await _renovarSesion();
    if (!renovado || accessToken == null) {
      throw ApiException(
        status == AuthStatus.autenticado ? 0 : 401,
        status == AuthStatus.autenticado
            ? 'No se pudo renovar la sesion. Revisa tu conexion.'
            : 'Tu sesion expiro. Inicia sesion de nuevo.',
      );
    }
    return accessToken!;
  }

  /// Una sola renovacion a la vez: el refresh token rota en cada uso, asi que dos
  /// renovaciones en paralelo harian que la segunda se lea como "reuso" y el
  /// servidor cierre todas las sesiones.
  Future<bool> _renovarSesion() =>
      _refrescando ??= _renovarSesionInterno().whenComplete(() => _refrescando = null);

  Future<bool> _renovarSesionInterno() async {
    final refreshGuardado = await _tokenStorage.leerRefreshToken();
    if (refreshGuardado == null) {
      await _cerrarSesionLocal();
      return false;
    }

    try {
      final tokens = await _authApi.refresh(refreshGuardado);
      await _aplicarTokens(tokens);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) await _cerrarSesionLocal();
      return false;
    } catch (_) {
      // Sin conexion u otro fallo transitorio: no se cierra la sesion.
      return false;
    }
  }

  Future<void> _cerrarSesionLocal() async {
    _temporizadorRefresh?.cancel();
    await _tokenStorage.limpiar();
    accessToken = null;
    _accesoExpiraUtc = null;
    usuarioActual = null;
    status = AuthStatus.noAutenticado;
    notifyListeners();
  }

  void _programarRenovacion(DateTime expiraUtc) {
    _temporizadorRefresh?.cancel();
    var espera = expiraUtc.difference(DateTime.now().toUtc()) - const Duration(seconds: 60);
    if (espera < const Duration(seconds: 5)) espera = const Duration(seconds: 5);
    _temporizadorRefresh = Timer(espera, () {
      if (status == AuthStatus.autenticado) _renovarSesion();
    });
  }

  @override
  void dispose() {
    _temporizadorRefresh?.cancel();
    super.dispose();
  }

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

    await _cerrarSesionLocal();
  }

  Future<void> _aplicarTokens(AuthTokens tokens) async {
    accessToken = tokens.accessToken;
    _accesoExpiraUtc = tokens.accessTokenExpiraUtc.toUtc();
    _programarRenovacion(_accesoExpiraUtc!);
    usuarioActual = tokens.usuario;
    await _tokenStorage.guardarRefreshToken(tokens.refreshToken);
    status = AuthStatus.autenticado;
    notifyListeners();
  }
}
