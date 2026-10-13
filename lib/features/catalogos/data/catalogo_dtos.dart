class TipoAnimalDto {
  final String id;
  final String nombre;
  final int cantidadCortes;

  TipoAnimalDto({required this.id, required this.nombre, required this.cantidadCortes});

  factory TipoAnimalDto.fromJson(Map<String, dynamic> json) => TipoAnimalDto(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        cantidadCortes: json['cantidadCortes'] as int,
      );
}

class CorteDto {
  final String id;
  final String tipoAnimalId;
  final String tipoAnimalNombre;
  final String nombre;
  final String unidadVenta;
  final double precioBase;
  final double stockMinimo;

  CorteDto({
    required this.id,
    required this.tipoAnimalId,
    required this.tipoAnimalNombre,
    required this.nombre,
    required this.unidadVenta,
    required this.precioBase,
    required this.stockMinimo,
  });

  factory CorteDto.fromJson(Map<String, dynamic> json) => CorteDto(
        id: json['id'] as String,
        tipoAnimalId: json['tipoAnimalId'] as String,
        tipoAnimalNombre: json['tipoAnimalNombre'] as String,
        nombre: json['nombre'] as String,
        unidadVenta: json['unidadVenta'] as String,
        precioBase: (json['precioBase'] as num).toDouble(),
        stockMinimo: (json['stockMinimo'] as num).toDouble(),
      );
}
