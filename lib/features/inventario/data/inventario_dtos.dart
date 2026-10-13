class InventarioItemDto {
  final String corteId;
  final String corteNombre;
  final String unidadVenta;
  final double stockActual;
  final double stockMinimo;
  final bool enAlerta;

  InventarioItemDto({
    required this.corteId,
    required this.corteNombre,
    required this.unidadVenta,
    required this.stockActual,
    required this.stockMinimo,
    required this.enAlerta,
  });

  factory InventarioItemDto.fromJson(Map<String, dynamic> json) => InventarioItemDto(
        corteId: json['corteId'] as String,
        corteNombre: json['corteNombre'] as String,
        unidadVenta: json['unidadVenta'] as String,
        stockActual: (json['stockActual'] as num).toDouble(),
        stockMinimo: (json['stockMinimo'] as num).toDouble(),
        enAlerta: json['enAlerta'] as bool,
      );
}

class MovimientoDto {
  final String id;
  final String tipoMovimiento;
  final double cantidad;
  final String? motivo;
  final String? usuarioNombre;
  final DateTime fecha;

  MovimientoDto({
    required this.id,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.motivo,
    required this.usuarioNombre,
    required this.fecha,
  });

  factory MovimientoDto.fromJson(Map<String, dynamic> json) => MovimientoDto(
        id: json['id'] as String,
        tipoMovimiento: json['tipoMovimiento'] as String,
        cantidad: (json['cantidad'] as num).toDouble(),
        motivo: json['motivo'] as String?,
        usuarioNombre: json['usuarioNombre'] as String?,
        fecha: DateTime.parse(json['fecha'] as String),
      );
}
