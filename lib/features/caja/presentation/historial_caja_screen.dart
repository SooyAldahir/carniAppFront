import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pos/data/pos_dtos.dart' show dinero;
import '../../pos/presentation/dialogos.dart' show mostrarTicketTexto;
import '../data/caja_api.dart';
import '../data/caja_dtos.dart';
import 'caja_widgets.dart';

/// Lista de cortes recientes; al tocar uno se ve el detalle, su ticket y (con permiso) reabrir el ultimo.
class HistorialCajaScreen extends StatefulWidget {
  final bool puedeReabrir;

  const HistorialCajaScreen({super.key, required this.puedeReabrir});

  @override
  State<HistorialCajaScreen> createState() => _HistorialCajaScreenState();
}

class _HistorialCajaScreenState extends State<HistorialCajaScreen> {
  final _api = CajaApi(ApiClient());
  late AuthProvider _auth;
  List<CorteCajaResumenDto> _cortes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cortes = await _api.historial(await _auth.obtenerTokenVigente());
      if (!mounted) return;
      setState(() {
        _cortes = cortes;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cortes de caja')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _cortes.isEmpty
                  ? const Center(child: Text('Todavia no hay cortes.'))
                  : ListView(
                      children: [
                        for (final c in _cortes)
                          ListTile(
                            leading: Icon(c.cerrado ? Icons.lock : Icons.lock_open),
                            title: Text(fechaHora(c.fechaInicio)),
                            subtitle: Text(
                              c.cerrado
                                  ? '${c.usuarioNombre ?? '-'} - ventas ${dinero(c.totalVentas ?? 0)} - '
                                      '${etiquetaDiferencia(c.diferencia ?? 0)} ${dinero((c.diferencia ?? 0).abs())}'
                                  : '${c.usuarioNombre ?? '-'} - turno abierto',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => DetalleCorteScreen(corteId: c.id, puedeReabrir: widget.puedeReabrir)))
                                .then((_) => _cargar()),
                          ),
                      ],
                    ),
    );
  }
}

class DetalleCorteScreen extends StatefulWidget {
  final String corteId;
  final bool puedeReabrir;

  const DetalleCorteScreen({super.key, required this.corteId, required this.puedeReabrir});

  @override
  State<DetalleCorteScreen> createState() => _DetalleCorteScreenState();
}

class _DetalleCorteScreenState extends State<DetalleCorteScreen> {
  final _api = CajaApi(ApiClient());
  late AuthProvider _auth;
  CorteCajaDto? _corte;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final corte = await _api.detalle(await _auth.obtenerTokenVigente(), widget.corteId);
      if (!mounted) return;
      setState(() {
        _corte = corte;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _ticket() async {
    try {
      final texto = await _api.ticket(await _auth.obtenerTokenVigente(), widget.corteId);
      if (mounted) await mostrarTicketTexto(context, texto);
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    }
  }

  Future<void> _reabrir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir corte'),
        content: const Text('El turno volvera a quedar abierto y se borrara el conteo de efectivo. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reabrir')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _api.reabrir(await _auth.obtenerTokenVigente(), widget.corteId);
      _avisar('Corte reabierto.');
      await _cargar();
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _corte;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del corte')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null || c == null
              ? Center(child: Text(_error ?? 'No se pudo cargar el corte.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ResumenCorteCard(corte: c),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: _ticket, icon: const Icon(Icons.receipt_long), label: const Text('Ver ticket del corte')),
                    if (c.cerrado && widget.puedeReabrir) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(onPressed: _reabrir, icon: const Icon(Icons.lock_open), label: const Text('Reabrir corte')),
                    ],
                  ],
                ),
    );
  }
}
