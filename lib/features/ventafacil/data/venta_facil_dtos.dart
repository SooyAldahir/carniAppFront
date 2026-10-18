/// Venta Facil: lotes de animal, rendimientos por corte y reparto estimado.
double _num(dynamic v) => (v as num).toDouble();

/// Convierte lo que escribe el usuario ("12,5" o "12.5") a numero; null si no es valido.
double? parsearDecimal(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

class RendimientoItemDto {
  final String corteId;
  final String corteNombre;
  final double precioBase;
  final double? porcentaje;
  final double? porcentajeAprendido;

  RendimientoItemDto({
    required this.corteId,
    required this.corteNombre,
    required this.precioBase,
    required this.porcentaje,
    this.porcentajeAprendido,
  });

  factory RendimientoItemDto.fromJson(Map<String, dynamic> json) => RendimientoItemDto(
        corteId: json['corteId'] as String,
        corteNombre: json['corteNombre'] as String,
        precioBase: _num(json['precioBase']),
        porcentaje: json['porcentaje'] == null ? null : _num(json['porcentaje']),
        porcentajeAprendido: json['porcentajeAprendido'] == null ? null : _num(json['porcentajeAprendido']),
      );
}

class RendimientosDto {
  final String tipoAnimalId;
  final List<RendimientoItemDto> cortes;
  final double totalPorcentaje;
  final int lotesMedidos;
  final int lotesParaAprender;

  /// true cuando ya hay suficientes lotes pesados para estimar sin pesar.
  final bool usaAprendido;

  RendimientosDto({
    required this.tipoAnimalId,
    required this.cortes,
    required this.totalPorcentaje,
    this.lotesMedidos = 0,
    this.lotesParaAprender = 3,
    this.usaAprendido = false,
  });

  factory RendimientosDto.fromJson(Map<String, dynamic> json) => RendimientosDto(
        tipoAnimalId: json['tipoAnimalId'] as String,
        cortes: (json['cortes'] as List)
            .map((e) => RendimientoItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPorcentaje: _num(json['totalPorcentaje']),
        lotesMedidos: (json['lotesMedidos'] as num?)?.toInt() ?? 0,
        lotesParaAprender: (json['lotesParaAprender'] as num?)?.toInt() ?? 3,
        usaAprendido: json['usaAprendido'] as bool? ?? false,
      );
}

class RepartoLineaDto {
  final String corteNombre;
  final double porcentaje;
  final double kgEstimados;
  final double precioBase;
  final double ventaEstimada;

  RepartoLineaDto({
    required this.corteNombre,
    required this.porcentaje,
    required this.kgEstimados,
    required this.precioBase,
    required this.ventaEstimada,
  });

  factory RepartoLineaDto.fromJson(Map<String, dynamic> json) => RepartoLineaDto(
        corteNombre: json['corteNombre'] as String,
        porcentaje: _num(json['porcentaje']),
        kgEstimados: _num(json['kgEstimados']),
        precioBase: _num(json['precioBase']),
        ventaEstimada: _num(json['ventaEstimada']),
      );
}

class RepartoDto {
  final String tipoAnimalNombre;
  final double pesoKg;
  final double precioCompra;
  final List<RepartoLineaDto> lineas;
  final double kgAsignados;
  final double kgMerma;
  final double costoPorKg;
  final double ventaEstimadaTotal;
  final double utilidadEstimada;
  final bool esEstimado;

  /// "Pesado", "Aprendido" o "Configurado".
  final String origen;
  final int lotesMedidos;
  final int lotesParaAprender;

  RepartoDto({
    required this.tipoAnimalNombre,
    required this.pesoKg,
    required this.precioCompra,
    required this.lineas,
    required this.kgAsignados,
    required this.kgMerma,
    required this.costoPorKg,
    required this.ventaEstimadaTotal,
    required this.utilidadEstimada,
    this.esEstimado = true,
    this.origen = 'Configurado',
    this.lotesMedidos = 0,
    this.lotesParaAprender = 3,
  });

  factory RepartoDto.fromJson(Map<String, dynamic> json) => RepartoDto(
        tipoAnimalNombre: json['tipoAnimalNombre'] as String,
        pesoKg: _num(json['pesoKg']),
        precioCompra: _num(json['precioCompra']),
        lineas: (json['lineas'] as List)
            .map((e) => RepartoLineaDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        kgAsignados: _num(json['kgAsignados']),
        kgMerma: _num(json['kgMerma']),
        costoPorKg: _num(json['costoPorKg']),
        ventaEstimadaTotal: _num(json['ventaEstimadaTotal']),
        utilidadEstimada: _num(json['utilidadEstimada']),
        esEstimado: json['esEstimado'] as bool? ?? true,
        origen: json['origen'] as String? ?? 'Configurado',
        lotesMedidos: (json['lotesMedidos'] as num?)?.toInt() ?? 0,
        lotesParaAprender: (json['lotesParaAprender'] as num?)?.toInt() ?? 3,
      );
}

class LoteDto {
  final String id;
  final String tipoAnimalNombre;
  final double pesoKg;
  final double precioCompra;
  final double costoPorKg;
  final DateTime fechaCompra;
  final bool esEstimado;

  LoteDto({
    required this.id,
    required this.tipoAnimalNombre,
    required this.pesoKg,
    required this.precioCompra,
    required this.costoPorKg,
    required this.fechaCompra,
    required this.esEstimado,
  });

  factory LoteDto.fromJson(Map<String, dynamic> json) => LoteDto(
        id: json['id'] as String,
        tipoAnimalNombre: json['tipoAnimalNombre'] as String,
        pesoKg: _num(json['pesoKg']),
        precioCompra: _num(json['precioCompra']),
        costoPorKg: _num(json['costoPorKg']),
        fechaCompra: DateTime.parse(json['fechaCompra'] as String).toLocal(),
        esEstimado: json['esEstimado'] as bool,
      );
}

/// Suma de porcentajes escritos en pantalla (ignora vacios e invalidos).
double sumaPorcentajes(Iterable<String> textos) =>
    textos.map((t) => parsearDecimal(t) ?? 0).fold(0.0, (a, b) => a + b);

/// Kilos capturados por corte (corteId -> kg). Ignora vacios y ceros; null si algun texto
/// no es un numero valido o es negativo.
Map<String, double>? kgDeTextos(Map<String, String> textos) {
  final resultado = <String, double>{};
  for (final e in textos.entries) {
    final t = e.value.trim();
    if (t.isEmpty) continue;
    final v = parsearDecimal(t);
    if (v == null || v < 0) return null;
    if (v > 0) resultado[e.key] = v;
  }
  return resultado;
}
