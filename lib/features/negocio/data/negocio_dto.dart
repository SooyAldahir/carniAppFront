/// RF-CONFIG-003: configuracion de marca del negocio.
class NegocioDto {
  final String id;
  final String nombreComercial;
  final String? logoUrl;
  final String? telefono;
  final String? redSocialPrincipal;
  final String? direccion;
  final String moneda;
  final String zonaHoraria;

  NegocioDto({
    required this.id,
    required this.nombreComercial,
    required this.logoUrl,
    required this.telefono,
    required this.redSocialPrincipal,
    required this.direccion,
    required this.moneda,
    required this.zonaHoraria,
  });

  factory NegocioDto.fromJson(Map<String, dynamic> json) => NegocioDto(
        id: json['id'] as String,
        nombreComercial: json['nombreComercial'] as String,
        logoUrl: json['logoUrl'] as String?,
        telefono: json['telefono'] as String?,
        redSocialPrincipal: json['redSocialPrincipal'] as String?,
        direccion: json['direccion'] as String?,
        moneda: json['moneda'] as String,
        zonaHoraria: json['zonaHoraria'] as String,
      );
}
