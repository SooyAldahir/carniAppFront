import 'package:flutter/material.dart';
import '../../clientes/data/clientes_dtos.dart';
import '../data/pos_dtos.dart';

/// Resultado del cobro: pagos exactos para el backend + cambio a entregar.
class ResultadoCobro {
  final List<PagoCaptura> pagos;
  final double cambio;

  /// Solo si el cajero cambio el % de cargo por credito en este cobro; null = el de siempre.
  final double? recargoPorcentaje;

  ResultadoCobro(this.pagos, this.cambio, {this.recargoPorcentaje});
}

/// RF-POS-008: pago simple o mixto. En Efectivo se captura lo que entrega el
/// cliente; si excede lo que falta, la diferencia se muestra como cambio y el
/// pago que se registra es solo lo aplicado a la venta (los pagos deben sumar
/// exactamente el total).
class CobroDialog extends StatefulWidget {
  final double total;
  final List<MetodoPagoDto> metodos;

  /// Cliente de la venta. Sin cliente no se ofrece Credito (RF-CRED-001).
  final ClienteDto? cliente;

  /// % de cargo sobre lo que se fia (lo define el servidor y se imprime en el ticket).
  final double recargoCreditoPorcentaje;

  /// Con 'pos.recargo.ajustar' el cajero puede cambiar el % solo en este cobro (0..[recargoMaximo]).
  final bool puedeAjustarRecargo;

  /// Con 'pos.recargo.reducir' solo puede bajarlo (de 0 al predeterminado).
  final bool puedeReducirRecargo;
  final double recargoMaximo;

  const CobroDialog({
    super.key,
    required this.total,
    required this.metodos,
    this.cliente,
    this.recargoCreditoPorcentaje = 0,
    this.puedeAjustarRecargo = false,
    this.puedeReducirRecargo = false,
    this.recargoMaximo = 30,
  });

  @override
  State<CobroDialog> createState() => _CobroDialogState();
}

class _CobroDialogState extends State<CobroDialog> {
  late final Map<String, TextEditingController> _controllers;

  /// Metodos que se muestran: Credito solo si la venta tiene cliente con credito.
  late final List<MetodoPagoDto> _metodos;

  double get _creditoDisponible => widget.cliente?.creditoDisponible ?? 0;

  late final TextEditingController _pctCtrl;

  bool get _puedeEditarPct => widget.puedeAjustarRecargo || widget.puedeReducirRecargo;

  /// Tope del campo: el maximo configurado si puede subir; el predeterminado si solo puede bajar.
  double get _pctMax => widget.puedeAjustarRecargo ? widget.recargoMaximo : widget.recargoCreditoPorcentaje;

  String _textoPct(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Porcentaje vigente en este cobro: el capturado (si puede ajustar) o el predeterminado.
  double get _pct {
    if (!_puedeEditarPct) return widget.recargoCreditoPorcentaje;
    return double.tryParse(_pctCtrl.text.trim()) ?? -1;
  }

  /// Para calculos que no deben romperse mientras el campo esta a medio escribir.
  double get _pctSeguro => _pctValido ? _pct : widget.recargoCreditoPorcentaje;

  bool get _pctValido => _pct >= 0 && _pct <= _pctMax;
  bool get _pctCambiado => _puedeEditarPct && _pctValido && (_pct - widget.recargoCreditoPorcentaje).abs() > 1e-9;

  /// Lo que se pide fiar (sin cargo) y el cargo que el servidor le sumara.
  double get _creditoBase =>
      redondear2(_metodos.where((m) => m.esCredito).fold(0.0, (s, m) => s + redondear2(_monto(m))));
  double get _recargo => _pctValido ? recargoDeCredito(_creditoBase, _pct) : 0;
  bool get _excedeCredito => _creditoBase > 0 && _pctValido && _creditoBase + _recargo > _creditoDisponible + 1e-9;

  @override
  void initState() {
    super.initState();
    _pctCtrl = TextEditingController(text: _textoPct(widget.recargoCreditoPorcentaje));
    _metodos = widget.metodos.where((m) => !m.esCredito || (widget.cliente != null && widget.cliente!.limiteCredito > 0)).toList();
    _controllers = {for (final m in _metodos) m.id: TextEditingController()};
    // Atajo comun: todo en efectivo.
    final efectivo = _metodos.where((m) => m.esEfectivo).firstOrNull;
    if (efectivo != null) _controllers[efectivo.id]!.text = widget.total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _pctCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _monto(MetodoPagoDto m) => double.tryParse(_controllers[m.id]!.text.trim()) ?? 0;

  /// Calcula pagos aplicados, cambio y si el cobro es valido con lo capturado.
  ({List<PagoCaptura> pagos, double cambio, double faltante, bool valido}) _calcular() {
    // El credito pedido no puede pasar del disponible del cliente.
    if (_excedeCredito || (_creditoBase > 0 && !_pctValido)) {
      return (pagos: const <PagoCaptura>[], cambio: 0, faltante: 0, valido: false);
    }

    final pagos = <PagoCaptura>[];
    var otros = 0.0;
    var efectivoRecibido = 0.0;
    String? efectivoId;

    for (final m in _metodos) {
      final monto = redondear2(_monto(m));
      if (monto <= 0) continue;
      if (m.esEfectivo) {
        efectivoRecibido = monto;
        efectivoId = m.id;
      } else {
        otros += monto;
        pagos.add(PagoCaptura(m.id, monto));
      }
    }

    otros = redondear2(otros);
    final restante = redondear2(widget.total - otros);
    var cambio = 0.0;

    if (restante < 0) {
      // Los pagos que no son efectivo pasan del total: no se puede dar cambio de tarjeta.
      return (pagos: pagos, cambio: 0, faltante: restante, valido: false);
    }

    if (restante > 0) {
      final aplicado = efectivoRecibido < restante ? efectivoRecibido : restante;
      if (efectivoId != null && aplicado > 0) pagos.add(PagoCaptura(efectivoId, aplicado));
      cambio = redondear2(efectivoRecibido - aplicado);
      final faltante = redondear2(restante - aplicado);
      return (pagos: pagos, cambio: cambio, faltante: faltante, valido: faltante == 0);
    }

    // restante == 0: ya cubierto sin efectivo (el efectivo capturado se ignora).
    return (pagos: pagos, cambio: 0, faltante: 0, valido: pagos.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final calculo = _calcular();

    return AlertDialog(
      title: Text('Cobrar ${dinero(widget.total)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.cliente != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Cliente: ${widget.cliente!.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              for (final m in _metodos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[m.id],
                          enabled: m.disponible,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: m.esEfectivo ? 'Efectivo recibido' : m.nombre,
                            helperText: m.esCredito
                                ? 'Disponible: ${dinero(_creditoDisponible)}'
                                    '${_pct > 0 ? ' · cargo ${_pct.toStringAsFixed(_pct % 1 == 0 ? 0 : 2)}%' : ''}'
                                : null,
                            prefixText: '\$ ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (m.disponible)
                        TextButton(
                          onPressed: () => setState(() {
                            for (final c in _controllers.values) {
                              c.clear();
                            }
                            final tope = m.esCredito
                                ? (maximoFiable(_creditoDisponible, _pctSeguro) < widget.total
                                    ? maximoFiable(_creditoDisponible, _pctSeguro)
                                    : widget.total)
                                : widget.total;
                            _controllers[m.id]!.text = tope.toStringAsFixed(2);
                          }),
                          child: const Text('Todo'),
                        ),
                    ],
                  ),
                ),
              const Divider(),
              if (_puedeEditarPct && _metodos.any((m) => m.esCredito))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _pctCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cargo por credito (%)',
                      helperText: 'Predeterminado ${_textoPct(widget.recargoCreditoPorcentaje)}%. Solo cambialo si hace falta.',
                      suffixText: '%',
                      errorText: _pctValido ? null : 'Entre 0 y ${_textoPct(_pctMax)}',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (_creditoBase > 0 && _recargo > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Cargo por credito: +${dinero(_recargo)}  ·  Total de la venta: ${dinero(widget.total + _recargo)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (_excedeCredito)
                Text('El credito pedido mas el cargo (${dinero(_creditoBase + _recargo)}) excede el disponible (${dinero(_creditoDisponible)}).',
                    style: const TextStyle(color: Colors.red))
              else if (calculo.faltante > 0)
                Text('Falta ${dinero(calculo.faltante)}', style: const TextStyle(color: Colors.red))
              else if (calculo.faltante < 0)
                Text('Los pagos sin efectivo exceden el total por ${dinero(-calculo.faltante)}',
                    style: const TextStyle(color: Colors.red)),
              if (calculo.cambio > 0)
                Text('Cambio: ${dinero(calculo.cambio)}',
                    style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: calculo.valido
              ? () => Navigator.pop(context, ResultadoCobro(calculo.pagos, calculo.cambio,
                  recargoPorcentaje: _creditoBase > 0 && _pctCambiado ? _pct : null))
              : null,
          child: const Text('Registrar venta'),
        ),
      ],
    );
  }
}
