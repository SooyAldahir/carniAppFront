import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pos/data/pos_dtos.dart' show dinero;
import '../../pos/presentation/dialogos.dart' show mostrarTicketTexto;
import '../data/caja_api.dart';
import '../data/caja_dtos.dart';
import '../../ventafacil/data/venta_facil_dtos.dart' show parsearDecimal;
import 'caja_widgets.dart';
import 'historial_caja_screen.dart';

/// Caja: abrir turno con fondo, registrar gastos, y cerrar con conteo de efectivo.
class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  final _api = CajaApi(ApiClient());
  final _fondoCtrl = TextEditingController(text: '0');

  late AuthProvider _auth;
  EstadoCajaDto? _estado;
  bool _cargando = true;
  bool _trabajando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _cargar();
  }

  @override
  void dispose() {
    _fondoCtrl.dispose();
    super.dispose();
  }

  Future<String> _token() => _auth.obtenerTokenVigente();

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final estado = await _api.actual(await _token());
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con el servidor.';
        _cargando = false;
      });
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Ejecuta una accion contra la API mostrando el error del servidor si falla.
  Future<T?> _ejecutar<T>(Future<T> Function(String token) accion) async {
    setState(() => _trabajando = true);
    try {
      return await accion(await _token());
    } on ApiException catch (e) {
      _avisar(e.mensaje);
      return null;
    } catch (_) {
      _avisar('No se pudo conectar con el servidor.');
      return null;
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _abrir() async {
    final fondo = parsearDecimal(_fondoCtrl.text);
    if (fondo == null || fondo < 0) {
      _avisar('Escribe el fondo inicial (0 si no hay).');
      return;
    }
    final corte = await _ejecutar((t) => _api.abrir(t, fondo));
    if (corte != null) {
      _avisar('Caja abierta.');
      await _cargar();
    }
  }

  Future<void> _gasto() async {
    final datos = await showDialog<({String concepto, double importe})>(
      context: context,
      builder: (_) => const _GastoDialog(),
    );
    if (datos == null) return;
    final corte = await _ejecutar((t) => _api.registrarGasto(t, datos.concepto, datos.importe));
    if (corte != null) {
      _avisar('Gasto registrado.');
      await _cargar();
    }
  }

  Future<void> _cerrar() async {
    final esperadoVisible = _estado?.corte;
    if (esperadoVisible == null) return;
    final datos = await showDialog<({double contado, String? notas})>(
      context: context,
      builder: (_) => _CierreDialog(esperado: esperadoVisible.efectivoEsperado),
    );
    if (datos == null) return;

    final corte = await _ejecutar((t) => _api.cerrar(t, datos.contado, datos.notas));
    if (corte == null || !mounted) return;
    await _cargar();
    if (!mounted) return;

    final dif = corte.diferencia ?? 0;
    final verTicket = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Caja cerrada'),
        content: Text(
          'Esperado: ${dinero(corte.efectivoEsperado)}\n'
          'Contado: ${dinero(corte.efectivoContado ?? 0)}\n'
          '${etiquetaDiferencia(dif)}: ${dinero(dif.abs())}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cerrar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ver ticket del corte')),
        ],
      ),
    );
    if (verTicket == true && mounted) {
      final texto = await _ejecutar((t) => _api.ticket(t, corte.id));
      if (texto != null && mounted) await mostrarTicketTexto(context, texto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeReabrir = _auth.usuarioActual?.tienePermiso('caja.reabrir') ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        actions: [
          IconButton(
            tooltip: 'Historial de cortes',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => HistorialCajaScreen(puedeReabrir: puedeReabrir)))
                .then((_) => _cargar()),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: (_estado?.abierta ?? false) ? _abierta() : _cerrada(),
                  ),
                ),
    );
  }

  List<Widget> _cerrada() => [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('No hay un turno de caja abierto. Abre uno indicando el efectivo con el que empiezas (fondo).'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fondoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Fondo inicial (\$)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _trabajando ? null : _abrir,
          icon: const Icon(Icons.lock_open),
          label: const Text('Abrir caja'),
        ),
      ];

  List<Widget> _abierta() => [
        ResumenCorteCard(corte: _estado!.corte!),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _trabajando ? null : _gasto,
          icon: const Icon(Icons.money_off),
          label: const Text('Registrar gasto'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _trabajando ? null : _cerrar,
          icon: const Icon(Icons.lock),
          label: const Text('Cerrar caja (contar efectivo)'),
        ),
      ];
}

class _GastoDialog extends StatefulWidget {
  const _GastoDialog();

  @override
  State<_GastoDialog> createState() => _GastoDialogState();
}

class _GastoDialogState extends State<_GastoDialog> {
  final _concepto = TextEditingController();
  final _importe = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _concepto.dispose();
    _importe.dispose();
    super.dispose();
  }

  void _guardar() {
    final concepto = _concepto.text.trim();
    final importe = parsearDecimal(_importe.text);
    if (concepto.isEmpty) {
      setState(() => _error = 'Escribe en que se gasto.');
    } else if (importe == null || importe <= 0) {
      setState(() => _error = 'El importe debe ser mayor a cero.');
    } else {
      Navigator.pop(context, (concepto: concepto, importe: importe));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar gasto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _concepto,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Concepto (ej. hielo, bolsas)'),
          ),
          TextField(
            controller: _importe,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Importe (\$)'),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

class _CierreDialog extends StatefulWidget {
  final double esperado;

  const _CierreDialog({required this.esperado});

  @override
  State<_CierreDialog> createState() => _CierreDialogState();
}

class _CierreDialogState extends State<_CierreDialog> {
  final _contado = TextEditingController();
  final _notas = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _contado.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _cerrar() {
    final contado = parsearDecimal(_contado.text);
    if (contado == null || contado < 0) {
      setState(() => _error = 'Escribe cuanto efectivo contaste en la caja.');
      return;
    }
    final notas = _notas.text.trim();
    Navigator.pop(context, (contado: contado, notas: notas.isEmpty ? null : notas));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cerrar caja'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('El sistema espera ${dinero(widget.esperado)} en efectivo. Cuenta lo que hay y escribelo.'),
          TextField(
            controller: _contado,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Efectivo contado (\$)'),
          ),
          TextField(
            controller: _notas,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _cerrar, child: const Text('Cerrar caja')),
      ],
    );
  }
}
