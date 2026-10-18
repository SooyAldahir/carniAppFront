/// Redondeo a centavos igual que el backend (Math.Round AwayFromZero a 2 decimales).
double redondear2(double valor) => (valor * 100).roundToDouble() / 100;

String dinero(num valor) => '\$${valor.toStringAsFixed(2)}';

String cantidadTexto(double cantidad) {
  final texto = cantidad.toStringAsFixed(3);
  return texto.replaceFirst(RegExp(r'\.?0+$'), '');
}

class CortePosDto {
  final String corteId;
  final String nombre;
  final String tipoAnimal;
  final String unidadVenta;
  final double precioBase;
  final double stockActual;

  CortePosDto({
    required this.corteId,
    required this.nombre,
    required this.tipoAnimal,
    required this.unidadVenta,
    required this.precioBase,
    required this.stockActual,
  });

  bool get esPieza => unidadVenta == 'Pieza';
  String get unidadCorta => esPieza ? 'pza' : 'kg';

  factory CortePosDto.fromJson(Map<String, dynamic> json) => CortePosDto(
        corteId: json['corteId'] as String,
        nombre: json['nombre'] as String,
        tipoAnimal: json['tipoAnimal'] as String,
        unidadVenta: json['unidadVenta'] as String,
        precioBase: (json['precioBase'] as num).toDouble(),
        stockActual: (json['stockActual'] as num).toDouble(),
      );
}

class MetodoPagoDto {
  final String id;
  final String nombre;
  final bool disponible;

  MetodoPagoDto({required this.id, required this.nombre, required this.disponible});

  bool get esEfectivo => nombre.toLowerCase() == 'efectivo';

  factory MetodoPagoDto.fromJson(Map<String, dynamic> json) => MetodoPagoDto(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        disponible: json['disponible'] as bool,
      );
}

/// Descuento capturado por la cajera: porcentaje o monto fijo (RF-POS-004).
/// El servidor siempre recibe pesos; el porcentaje solo existe en el cliente.
class DescuentoCaptura {
  final bool porcentaje;
  final double valor;

  const DescuentoCaptura.porcentaje(this.valor) : porcentaje = true;
  const DescuentoCaptura.monto(this.valor) : porcentaje = false;

  /// Descuento en pesos sobre [base], acotado a [0, base].
  double aplicarSobre(double base) {
    var d = porcentaje ? redondear2(base * valor / 100) : redondear2(valor);
    if (d < 0) d = 0;
    if (d > base) d = base;
    return d;
  }

  String get etiqueta => porcentaje ? '${cantidadTexto(valor)}%' : dinero(valor);
}

/// Linea del carrito (solo vive en el cliente hasta cobrar).
class LineaCarrito {
  final CortePosDto corte;
  double cantidad;
  DescuentoCaptura? descuentoCaptura;

  LineaCarrito(this.corte, this.cantidad);

  double get bruto => redondear2(cantidad * corte.precioBase);
  double get descuento => descuentoCaptura?.aplicarSobre(bruto) ?? 0;
  double get importe => redondear2(bruto - descuento);
}

/// Pago capturado en la pantalla de cobro.
class PagoCaptura {
  final String metodoPagoId;
  final double importe;

  PagoCaptura(this.metodoPagoId, this.importe);
}

class VentaLineaDto {
  final String corteNombre;
  final String unidadVenta;
  final double cantidad;
  final double precioUnitario;
  final double importe;
  final double descuento;

  VentaLineaDto({
    required this.corteNombre,
    required this.unidadVenta,
    required this.cantidad,
    required this.precioUnitario,
    required this.importe,
    this.descuento = 0,
  });

  factory VentaLineaDto.fromJson(Map<String, dynamic> json) => VentaLineaDto(
        corteNombre: json['corteNombre'] as String,
        unidadVenta: json['unidadVenta'] as String,
        cantidad: (json['cantidad'] as num).toDouble(),
        precioUnitario: (json['precioUnitario'] as num).toDouble(),
        importe: (json['importe'] as num).toDouble(),
        descuento: (json['descuento'] as num?)?.toDouble() ?? 0,
      );
}

class VentaPagoDto {
  final String metodoPago;
  final double importe;

  VentaPagoDto({required this.metodoPago, required this.importe});

  factory VentaPagoDto.fromJson(Map<String, dynamic> json) => VentaPagoDto(
        metodoPago: json['metodoPago'] as String,
        importe: (json['importe'] as num).toDouble(),
      );
}

class VentaDto {
  final String id;
  final int folio;
  final DateTime fecha;
  final String estado;
  final String? motivoAnulacion;
  final String? usuarioNombre;
  final double subtotal;
  final double descuento;
  final double total;
  final List<VentaLineaDto> lineas;
  final List<VentaPagoDto> pagos;

  VentaDto({
    required this.id,
    required this.folio,
    required this.fecha,
    required this.estado,
    required this.motivoAnulacion,
    required this.usuarioNombre,
    required this.subtotal,
    required this.descuento,
    required this.total,
    required this.lineas,
    required this.pagos,
  });

  bool get anulada => estado == 'Anulada';

  factory VentaDto.fromJson(Map<String, dynamic> json) => VentaDto(
        id: json['id'] as String,
        folio: json['folio'] as int,
        fecha: DateTime.parse(json['fecha'] as String).toLocal(),
        estado: json['estado'] as String,
        motivoAnulacion: json['motivoAnulacion'] as String?,
        usuarioNombre: json['usuarioNombre'] as String?,
        subtotal: (json['subtotal'] as num).toDouble(),
        descuento: (json['descuento'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        lineas: (json['lineas'] as List<dynamic>)
            .map((e) => VentaLineaDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagos: (json['pagos'] as List<dynamic>)
            .map((e) => VentaPagoDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class VentaResumenDto {
  final String id;
  final int folio;
  final DateTime fecha;
  final String estado;
  final String? usuarioNombre;
  final double total;

  VentaResumenDto({
    required this.id,
    required this.folio,
    required this.fecha,
    required this.estado,
    required this.usuarioNombre,
    required this.total,
  });

  bool get anulada => estado == 'Anulada';

  factory VentaResumenDto.fromJson(Map<String, dynamic> json) => VentaResumenDto(
        id: json['id'] as String,
        folio: json['folio'] as int,
        // El backend manda UTC; se muestra en hora local de la caja.
        fecha: DateTime.parse(json['fecha'] as String).toLocal(),
        estado: json['estado'] as String,
        usuarioNombre: json['usuarioNombre'] as String?,
        total: (json['total'] as num).toDouble(),
      );
}
