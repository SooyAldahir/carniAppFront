import 'package:flutter/material.dart';
import '../../../core/hardware/ticket_printer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/pos_api.dart';
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

/// RF-POS-004: captura un descuento en porcentaje o en pesos sobre [baseMonto].
/// Devuelve null si se cancela; `DescuentoCaptura.monto(0)` significa "quitar el descuento".
Future<DescuentoCaptura?> pedirDescuento(
  BuildContext context, {
  required String titulo,
  required double baseMonto,
  DescuentoCaptura? actual,
}) =>
    showDialog<DescuentoCaptura>(
      context: context,
      builder: (_) => _DescuentoDialog(titulo: titulo, baseMonto: baseMonto, actual: actual),
    );

class _DescuentoDialog extends StatefulWidget {
  final String titulo;
  final double baseMonto;
  final DescuentoCaptura? actual;

  const _DescuentoDialog({required this.titulo, required this.baseMonto, required this.actual});

  @override
  State<_DescuentoDialog> createState() => _DescuentoDialogState();
}

class _DescuentoDialogState extends State<_DescuentoDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  late bool _porcentaje;

  @override
  void initState() {
    super.initState();
    _porcentaje = widget.actual?.porcentaje ?? true;
    _controller = TextEditingController(text: widget.actual == null ? '' : cantidadTexto(widget.actual!.valor));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _valor => double.tryParse(_controller.text.trim()) ?? 0;

  void _aplicar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _porcentaje ? DescuentoCaptura.porcentaje(_valor) : DescuentoCaptura.monto(_valor));
  }

  @override
  Widget build(BuildContext context) {
    final enPesos = _porcentaje ? redondear2(widget.baseMonto * _valor / 100) : _valor;

    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Importe sobre el que se aplica: ${dinero(widget.baseMonto)}'),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('%')),
                ButtonSegment(value: false, label: Text('\$')),
              ],
              selected: {_porcentaje},
              onSelectionChanged: (v) => setState(() => _porcentaje = v.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: _porcentaje ? 'Porcentaje' : 'Monto', suffixText: _porcentaje ? '%' : null, prefixText: _porcentaje ? null : '\$ '),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final valor = double.tryParse((v ?? '').trim());
                if (valor == null || valor <= 0) return 'Captura un valor mayor a cero';
                if (_porcentaje && valor > 100) return 'Maximo 100%';
                if (!_porcentaje && valor > widget.baseMonto) return 'Excede el importe';
                return null;
              },
              onFieldSubmitted: (_) => _aplicar(),
            ),
            if (_valor > 0) ...[
              const SizedBox(height: 8),
              Text('Descuento: ${dinero(enPesos)}'),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.actual != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const DescuentoCaptura.monto(0)),
            child: const Text('Quitar'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _aplicar, child: const Text('Aplicar')),
      ],
    );
  }
}

/// RF-POS-010: baja el ticket de una venta y lo muestra (ticket digital: copiar/compartir).
Future<void> verTicket(BuildContext context, PosApi api, String ventaId) async {
  final auth = context.read<AuthProvider>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final token = await auth.obtenerTokenVigente();
    final texto = await api.ticket(token, ventaId);
    if (!context.mounted) return;
    await showDialog<void>(context: context, builder: (_) => _TicketDialog(texto: texto));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('No se pudo cargar el ticket.')));
  }
}

class _TicketDialog extends StatelessWidget {
  final String texto;

  const _TicketDialog({required this.texto});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ticket'),
      content: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SelectableText(
            texto,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black, height: 1.3),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Configurar impresora',
          icon: const Icon(Icons.settings),
          onPressed: () => showDialog<void>(context: context, builder: (_) => const _ImpresoraDialog()),
        ),
        TextButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('Imprimir'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await TicketPrinter().imprimir(texto);
              messenger.showSnackBar(const SnackBar(content: Text('Ticket enviado a la impresora.')));
            } on ImpresoraException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
            }
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copiar'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: texto));
            messenger.showSnackBar(const SnackBar(content: Text('Ticket copiado.')));
          },
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

/// Configura la impresora termica de red (IP y puerto) y permite una impresion de prueba.
class _ImpresoraDialog extends StatefulWidget {
  const _ImpresoraDialog();

  @override
  State<_ImpresoraDialog> createState() => _ImpresoraDialogState();
}

class _ImpresoraDialogState extends State<_ImpresoraDialog> {
  final _printer = TicketPrinter();
  final _hostCtrl = TextEditingController();
  final _puertoCtrl = TextEditingController(text: '9100');
  String? _estado;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _printer.cargarConfig().then((cfg) {
      if (!mounted || cfg == null) return;
      _hostCtrl.text = cfg.host;
      _puertoCtrl.text = cfg.puerto.toString();
    });
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _puertoCtrl.dispose();
    super.dispose();
  }

  ImpresoraConfig get _config => ImpresoraConfig(_hostCtrl.text, int.tryParse(_puertoCtrl.text) ?? 0);

  Future<void> _guardar({required bool probar}) async {
    if (!_config.valida) {
      setState(() => _estado = 'Escribe una IP y un puerto validos.');
      return;
    }
    setState(() {
      _ocupado = true;
      _estado = null;
    });
    try {
      await _printer.guardarConfig(_config);
      if (probar) {
        await _printer.imprimir('CarniApp\nPrueba de impresion\nAcentos: ñ á é\n', config: _config);
      }
      if (!mounted) return;
      if (probar) {
        setState(() => _estado = 'Prueba enviada. Configuracion guardada.');
      } else {
        Navigator.pop(context);
      }
    } on ImpresoraException catch (e) {
      if (mounted) setState(() => _estado = e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Impresora de tickets'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(labelText: 'IP de la impresora', hintText: '192.168.1.50'),
          ),
          TextField(
            controller: _puertoCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Puerto (normalmente 9100)'),
          ),
          if (_estado != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_estado!)),
        ],
      ),
      actions: [
        TextButton(onPressed: _ocupado ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: _ocupado ? null : () => _guardar(probar: true), child: const Text('Probar')),
        FilledButton(onPressed: _ocupado ? null : () => _guardar(probar: false), child: const Text('Guardar')),
      ],
    );
  }
}
