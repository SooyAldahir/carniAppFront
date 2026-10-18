import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/pos_api.dart';
import '../data/pos_dtos.dart';
import 'dialogos.dart';

/// Ventas del dia (hora local de la caja) con detalle de ticket y anulacion
/// con motivo obligatorio (RN-003, permiso 'pos.anular').
class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final PosApi _api = PosApi(ApiClient());
  late AuthProvider _auth;
  late bool _puedeAnular;

  List<VentaResumenDto> _ventas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _puedeAnular = _auth.usuarioActual?.tienePermiso('pos.anular') ?? false;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final ahora = DateTime.now();
      final inicioDia = DateTime(ahora.year, ahora.month, ahora.day);
      final token = await _auth.obtenerTokenVigente();
      final ventas = await _api.listar(token, desde: inicioDia, hasta: inicioDia.add(const Duration(days: 1)));
      if (!mounted) return;
      setState(() {
        _ventas = ventas;
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

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  String _hora(DateTime f) =>
      '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  Future<void> _verDetalle(VentaResumenDto resumen) async {
    try {
      final token = await _auth.obtenerTokenVigente();
      final venta = await _api.obtener(token, resumen.id);
      if (!mounted) return;

      final anular = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Venta #${venta.folio}${venta.anulada ? ' (ANULADA)' : ''}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_hora(venta.fecha)}  ·  ${venta.usuarioNombre ?? ''}',
                      style: const TextStyle(color: Colors.grey)),
                  const Divider(),
                  for (final l in venta.lineas)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                                '${l.corteNombre}  ${cantidadTexto(l.cantidad)} ${l.unidadVenta == 'Pieza' ? 'pza' : 'kg'}'
                                ' × ${dinero(l.precioUnitario)}'
                                '${l.descuento > 0 ? '\n  Descuento: -${dinero(l.descuento)}' : ''}'),
                          ),
                          Text(dinero(l.importe)),
                        ],
                      ),
                    ),
                  const Divider(),
                  if (venta.descuento > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('Subtotal'), Text(dinero(venta.subtotal))],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descuento'),
                        Text('-${dinero(venta.descuento)}', style: const TextStyle(color: AppColors.stockAgotado)),
                      ],
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(dinero(venta.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final p in venta.pagos) Text('${p.metodoPago}: ${dinero(p.importe)}'),
                  if (venta.anulada && venta.motivoAnulacion != null) ...[
                    const SizedBox(height: 8),
                    Text('Motivo de anulacion: ${venta.motivoAnulacion}',
                        style: const TextStyle(color: AppColors.stockAgotado)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ticket'),
              onPressed: () => verTicket(context, _api, venta.id),
            ),
            if (_puedeAnular && !venta.anulada)
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Anular venta', style: TextStyle(color: AppColors.stockAgotado)),
              ),
            FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cerrar')),
          ],
        ),
      );

      if (anular == true) await _anular(venta);
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    } catch (_) {
      _avisar('No se pudo conectar con el servidor.');
    }
  }

  Future<void> _anular(VentaDto venta) async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Anular venta #${venta.folio}',
      descripcion: 'El stock de esta venta se repondra al inventario.',
      textoConfirmar: 'Anular',
    );
    if (motivo == null) return;

    try {
      final token = await _auth.obtenerTokenVigente();
      await _api.anular(token, venta.id, motivo);
      _avisar('Venta #${venta.folio} anulada.');
      await _cargar();
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    } catch (_) {
      _avisar('No se pudo conectar con el servidor.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDia = _ventas.where((v) => !v.anulada).fold<double>(0, (s, v) => s + v.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas del dia'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
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
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: AppColors.hueso,
                      child: Text('Vendido hoy: ${dinero(totalDia)}  (${_ventas.where((v) => !v.anulada).length} ventas)',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Expanded(
                      child: _ventas.isEmpty
                          ? const Center(child: Text('Todavia no hay ventas hoy.'))
                          : ListView.separated(
                              itemCount: _ventas.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final v = _ventas[i];
                                return ListTile(
                                  onTap: () => _verDetalle(v),
                                  title: Text(
                                    'Venta #${v.folio}',
                                    style: TextStyle(decoration: v.anulada ? TextDecoration.lineThrough : null),
                                  ),
                                  subtitle: Text('${_hora(v.fecha)}  ·  ${v.usuarioNombre ?? ''}'
                                      '${v.anulada ? '  ·  ANULADA' : ''}'),
                                  trailing: Text(
                                    dinero(v.total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: v.anulada ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
