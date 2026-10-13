/// Modelo de la respuesta de GET /api/health
class HealthStatus {
  final String estado;
  final bool baseDeDatosConectada;
  final String? nombreNegocio;
  final DateTime horaServidorUtc;

  HealthStatus({
    required this.estado,
    required this.baseDeDatosConectada,
    required this.nombreNegocio,
    required this.horaServidorUtc,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      estado: json['estado'] as String,
      baseDeDatosConectada: json['baseDeDatosConectada'] as bool,
      nombreNegocio: json['nombreNegocio'] as String?,
      horaServidorUtc: DateTime.parse(json['horaServidorUtc'] as String),
    );
  }
}
