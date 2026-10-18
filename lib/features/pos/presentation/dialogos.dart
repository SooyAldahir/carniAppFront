import 'package:flutter/material.dart';
import '../data/pos_dtos.dart';

/// Pide la cantidad de un corte (kg con decimales o piezas enteras).
/// Devuelve null si se cancela.
///
/// Los controllers viven DENTRO de un StatefulWidget y se liberan en su dispose():
/// liberarlos justo despues de `await showDialog` rompe la animacion de cierre
/// del dialogo (el TextField sigue en pantalla unos milisegundos) y provoca
/// errores en cascada del framework.
Future<double?> pedirCantidad(BuildContext context, CortePosDto corte, double disponible) =>
    showDialog<double>(
      context: context,
      builder: (_) => _CantidadDialog(corte: corte, disponible: disponible < 0 ? 0 : disponible),
    );

class _CantidadDialog extends StatefulWidget {
  final CortePosDto corte;
  final double disponible;

  const _CantidadDialog({required this.corte, required this.disponible});

  @override
  State<_CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<_CantidadDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _aceptar() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, double.parse(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final corte = widget.corte;
    return AlertDialog(
      title: Text(corte.nombre),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${dinero(corte.precioBase)} por ${corte.unidadCorta}  ·  '
                'disponible: ${cantidadTexto(widget.disponible)} ${corte.unidadCorta}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: !corte.esPieza),
              decoration: InputDecoration(
                labelText: corte.esPieza ? 'Piezas' : 'Peso (kg)',
                suffixText: corte.unidadCorta,
              ),
              validator: (v) {
                final valor = double.tryParse((v ?? '').trim());
                if (valor == null || valor <= 0) return 'Captura una cantidad mayor a cero';
                if (corte.esPieza && valor != valor.truncateToDouble()) {
                  return 'Se vende por pieza: usa un entero';
                }
                if (valor > widget.disponible + 0.0000001) {
                  return 'Solo hay ${cantidadTexto(widget.disponible)} ${corte.unidadCorta} disponibles';
                }
                return null;
              },
              onFieldSubmitted: (_) => _aceptar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _aceptar, child: const Text('Agregar')),
      ],
    );
  }
}

/// Pide un motivo obligatorio (ej. anulacion de venta). Devuelve null si se cancela.
Future<String?> pedirMotivo(
  BuildContext context, {
  required String titulo,
  required String descripcion,
  required String textoConfirmar,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _MotivoDialog(titulo: titulo, descripcion: descripcion, textoConfirmar: textoConfirmar),
    );

class _MotivoDialog extends StatefulWidget {
  final String titulo;
  final String descripcion;
  final String textoConfirmar;

  const _MotivoDialog({required this.titulo, required this.descripcion, required this.textoConfirmar});

  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.descripcion),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Motivo (obligatorio)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El motivo es obligatorio' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.pop(context, _controller.text.trim());
          },
          child: Text(widget.textoConfirmar),
        ),
      ],
    );
  }
}
