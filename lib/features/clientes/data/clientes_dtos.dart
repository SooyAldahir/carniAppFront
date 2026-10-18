class ClienteDto {
  final String id;
  final String nombre;
  final String? telefono;
  final String? direccion;
  final String? referencias;
  final double limiteCredito;
  final double saldoCredito;
  final double creditoDisponible;

  ClienteDto({
    required this.id,
    required this.nombre,
    this.telefono,
    this.direccion,
    this.referencias,
    required this.limiteCredito,
    required this.saldoCredito,
    required this.creditoDisponible,
  });

  bool get tieneSaldo => saldoCredito > 0;

  factory ClienteDto.fromJson(Map<String, dynamic> json) => ClienteDto(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        telefono: json['telefono'] as String?,
        direccion: json['direccion'] as String?,
        referencias: json['referencias'] as String?,
        limiteCredito: (json['limiteCredito'] as num).toDouble(),
        saldoCredito: (json['saldoCredito'] as num).toDouble(),
        creditoDisponible: (json['creditoDisponible'] as num).toDouble(),
      );
}

class AbonoDto {
  final String id;
  final double importe;
  final DateTime fecha;
  final String? usuarioNombre;

  AbonoDto({required this.id, required this.importe, required this.fecha, this.usuarioNombre});

  factory AbonoDto.fromJson(Map<String, dynamic> json) => AbonoDto(
        id: json['id'] as String,
        importe: (json['importe'] as num).toDouble(),
        fecha: DateTime.parse(json['fecha'] as String).toLocal(),
        usuarioNombre: json['usuarioNombre'] as String?,
      );
}
