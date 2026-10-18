import 'package:flutter/material.dart';
import '../data/pos_dtos.dart';

/// Resultado del cobro: pagos exactos para el backend + cambio a entregar.
class ResultadoCobro {
  final List<PagoCaptura> pagos;
  final double cambio;

  ResultadoCobro(this.pagos, this.cambio);
}

/// RF-POS-008: pago simple o mixto. En Efectivo se captura lo que entrega el
/// cliente; si excede lo que falta, la diferencia se muestra como cambio y el
/// pago que se registra es solo lo aplicado a la venta (los pagos deben sumar
/// exactamente el total).
class CobroDialog extends StatefulWidget {
  final double total;
  final List<MetodoPagoDto> metodos;

  const CobroDialog({super.key, required this.total, required this.metodos});

  @override
  State<CobroDialog> createState() => _CobroDialogState();
}

class _CobroDialogState extends State<CobroDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {for (final m in widget.metodos) m.id: TextEditingController()};
    // Atajo comun: todo en efectivo.
    final efectivo = widget.metodos.where((m) => m.esEfectivo).firstOrNull;
    if (efectivo != null) _controllers[efectivo.id]!.text = widget.total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _monto(MetodoPagoDto m) => double.tryParse(_controllers[m.id]!.text.trim()) ?? 0;

  /// Calcula pagos aplicados, cambio y si el cobro es valido con lo capturado.
  ({List<PagoCaptura> pagos, double cambio, double faltante, bool valido}) _calcular() {
    final pagos = <PagoCaptura>[];
    var otros = 0.0;
    var efectivoRecibido = 0.0;
    String? efectivoId;

    for (final m in widget.metodos) {
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
              for (final m in widget.metodos)
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
                            helperText: m.disponible ? null : 'Disponible con clientes (Sprint 7)',
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
                            _controllers[m.id]!.text = widget.total.toStringAsFixed(2);
                          }),
                          child: const Text('Todo'),
                        ),
                    ],
                  ),
                ),
              const Divider(),
              if (calculo.faltante > 0)
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
              ? () => Navigator.pop(context, ResultadoCobro(calculo.pagos, calculo.cambio))
              : null,
          child: const Text('Registrar venta'),
        ),
      ],
    );
  }
}
