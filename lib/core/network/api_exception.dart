/// Error de API con el codigo de estado HTTP y el mensaje que mando
/// el backend (si lo mando), para que las pantallas puedan mostrar
/// mensajes de negocio reales (ej. "Cuenta bloqueada...") en vez de
/// un error generico.
class ApiException implements Exception {
  final int statusCode;
  final String mensaje;

  ApiException(this.statusCode, this.mensaje);

  @override
  String toString() => mensaje;
}
