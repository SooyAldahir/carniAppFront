/// RF-CAJA: turno de caja, gastos y corte.
double _num(dynamic v) => (v as num).toDouble();

double? _numOpt(dynamic v) => v == null ? null : (v as num).toDouble();

DateTime? _fechaOpt(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

class MetodoTotalDto {
  final String metodo;
  final double importe;

  MetodoTotalDto({required this.metodo, required this.importe});

  factory MetodoTotalDto.fromJson(Map<String, dynamic> json) =>
      MetodoTotalDto(metodo: json['metodo'] as String, importe: _num(json['importe']));
}

class GastoCajaDto {
  final String id;
  final String concepto;
  final double importe;
  final String? usuarioNombre;
  final DateTime fecha;

  GastoCajaDto({
    required this.id,
    required this.concepto,
    required this.importe,
    required this.usuarioNombre,
    required this.fecha,
  });

  factory GastoCajaDto.fromJson(Map<String, dynamic> json) => GastoCajaDto(
        id: json['id'] as String,
        concepto: json['concepto'] as String,
        importe: _num(json['importe']),
        usuarioNombre: json['usuarioNombre'] as String?,
        fecha: DateTime.parse(json['fecha'] as String).toLocal(),
      );
}

class CorteCajaDto {
  final String id;
  final String estado;
  final String? usuarioNombre;
  final DateTime fechaInicio;
  final DateTime? fechaCierre;
  final double fondoInicial;
  final int numeroVentas;
  final int ventasAnuladas;
  final double totalVentas;
  final List<MetodoTotalDto> porMetodo;
  final double ventasEfectivo;
  final double abonosEfectivo;
  final double totalGastos;
  final List<GastoCajaDto> gastos;
  final double efectivoEsperado;
  final double? efectivoContado;
  final double? diferencia;
  final String? notas;

  CorteCajaDto({
    required this.id,
    required this.estado,
    required this.usuarioNombre,
    required this.fechaInicio,
    required this.fechaCierre,
    required this.fondoInicial,
    required this.numeroVentas,
    required this.ventasAnuladas,
    required this.totalVentas,
    required this.porMetodo,
    required this.ventasEfectivo,
    required this.abonosEfectivo,
    required this.totalGastos,
    required this.gastos,
    required this.efectivoEsperado,
    required this.efectivoContado,
    required this.diferencia,
    required this.notas,
  });

  bool get cerrado => estado == 'Cerrado';

  factory CorteCajaDto.fromJson(Map<String, dynamic> json) => CorteCajaDto(
        id: json['id'] as String,
        estado: json['estado'] as String,
        usuarioNombre: json['usuarioNombre'] as String?,
        fechaInicio: DateTime.parse(json['fechaInicio'] as String).toLocal(),
        fechaCierre: _fechaOpt(json['fechaCierre']),
        fondoInicial: _num(json['fondoInicial']),
        numeroVentas: (json['numeroVentas'] as num).toInt(),
        ventasAnuladas: (json['ventasAnuladas'] as num).toInt(),
        totalVentas: _num(json['totalVentas']),
        porMetodo: (json['porMetodo'] as List).map((e) => MetodoTotalDto.fromJson(e as Map<String, dynamic>)).toList(),
        ventasEfectivo: _num(json['ventasEfectivo']),
        abonosEfectivo: _num(json['abonosEfectivo']),
        totalGastos: _num(json['totalGastos']),
        gastos: (json['gastos'] as List).map((e) => GastoCajaDto.fromJson(e as Map<String, dynamic>)).toList(),
        efectivoEsperado: _num(json['efectivoEsperado']),
        efectivoContado: _numOpt(json['efectivoContado']),
        diferencia: _numOpt(json['diferencia']),
        notas: json['notas'] as String?,
      );
}

class EstadoCajaDto {
  final bool abierta;
  final CorteCajaDto? corte;

  EstadoCajaDto({required this.abierta, required this.corte});

  factory EstadoCajaDto.fromJson(Map<String, dynamic> json) => EstadoCajaDto(
        abierta: json['abierta'] as bool,
        corte: json['corte'] == null ? null : CorteCajaDto.fromJson(json['corte'] as Map<String, dynamic>),
      );
}

class CorteCajaResumenDto {
  final String id;
  final String estado;
  final String? usuarioNombre;
  final DateTime fechaInicio;
  final DateTime? fechaCierre;
  final double? totalVentas;
  final double? efectivoEsperado;
  final double? efectivoContado;
  final double? diferencia;

  CorteCajaResumenDto({
    required this.id,
    required this.estado,
    required this.usuarioNombre,
    required this.fechaInicio,
    required this.fechaCierre,
    required this.totalVentas,
    required this.efectivoEsperado,
    required this.efectivoContado,
    required this.diferencia,
  });

  bool get cerrado => estado == 'Cerrado';

  factory CorteCajaResumenDto.fromJson(Map<String, dynamic> json) => CorteCajaResumenDto(
        id: json['id'] as String,
        estado: json['estado'] as String,
        usuarioNombre: json['usuarioNombre'] as String?,
        fechaInicio: DateTime.parse(json['fechaInicio'] as String).toLocal(),
        fechaCierre: _fechaOpt(json['fechaCierre']),
        totalVentas: _numOpt(json['totalVentas']),
        efectivoEsperado: _numOpt(json['efectivoEsperado']),
        efectivoContado: _numOpt(json['efectivoContado']),
        diferencia: _numOpt(json['diferencia']),
      );
}

/// "Sobrante", "Faltante" o "Cuadra" segun la diferencia contado - esperado (con tolerancia de centavos).
String etiquetaDiferencia(double diferencia) {
  if (diferencia > 0.004) return 'Sobrante';
  if (diferencia < -0.004) return 'Faltante';
  return 'Cuadra';
}

String fechaHora(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
