/// Resumen del usuario autenticado: lo que el JWT ya trae decodificado
/// desde el backend (no hace falta otra llamada para saber rol/permisos).
class UsuarioResumen {
  final String id;
  final String nombreCompleto;
  final String nombreUsuario;
  final String? correo;
  final String rol;
  final List<String> permisos;

  UsuarioResumen({
    required this.id,
    required this.nombreCompleto,
    required this.nombreUsuario,
    required this.correo,
    required this.rol,
    required this.permisos,
  });

  bool tienePermiso(String clave) => permisos.contains(clave);

  factory UsuarioResumen.fromJson(Map<String, dynamic> json) => UsuarioResumen(
        id: json['id'] as String,
        nombreCompleto: json['nombreCompleto'] as String,
        nombreUsuario: json['nombreUsuario'] as String,
        correo: json['correo'] as String?,
        rol: json['rol'] as String,
        permisos: (json['permisos'] as List<dynamic>).cast<String>(),
      );
}

/// Par de tokens + usuario que regresa login/refresh/bootstrap-admin.
class AuthTokens {
  final String accessToken;
  final DateTime accessTokenExpiraUtc;
  final String refreshToken;
  final UsuarioResumen usuario;

  AuthTokens({
    required this.accessToken,
    required this.accessTokenExpiraUtc,
    required this.refreshToken,
    required this.usuario,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        accessTokenExpiraUtc: DateTime.parse(json['accessTokenExpiraUtc'] as String),
        refreshToken: json['refreshToken'] as String,
        usuario: UsuarioResumen.fromJson(json['usuario'] as Map<String, dynamic>),
      );
}
