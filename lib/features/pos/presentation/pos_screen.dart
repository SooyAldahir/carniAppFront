import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/pos_api.dart';
import '../data/pos_dtos.dart';
import 'cobro_dialog.dart';
import 'dialogos.dart';
import 'ventas_screen.dart';

/// RF-POS-001/002/008: punto de venta. Catalogo de cortes con precio y stock,
/// carrito (kg con decimales o piezas enteras) y cobro simple o mixto.
/// El servidor recalcula el total con el precio del catalogo y valida stock.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final PosApi _api = PosApi(ApiClient());
  late AuthProvider _auth;

  List<CortePosDto> _catalogo = [];
  List<MetodoPagoDto> _metodos = [];
  final List<LineaCarrito> _carrito = [];
  String _filtro = '';
  DescuentoCaptura? _descuentoTotalCaptura;
  late bool _puedeDescuento;
  bool _cargando = true;
  bool _cobrando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    final usuario = _auth.usuarioActual;
    _puedeDescuento = (usuario?.tienePermiso('pos.descuento') ?? false) ||
        (usuario?.tienePermiso('pos.descuento.alto') ?? false);
    _cargar();
  }

  double get _subtotalBruto => redondear2(_carrito.fold(0.0, (suma, l) => suma + l.bruto));
  double get _descuentoLineas => redondear2(_carrito.fold(0.0, (suma, l) => suma + l.descuento));
  double get _importeLineas => redondear2(_subtotalBruto - _descuentoLineas);
  double get _descuentoGlobal => _descuentoTotalCaptura?.aplicarSobre(_importeLineas) ?? 0;
  double get _descuentoTotal => redondear2(_descuentoLineas + _descuentoGlobal);
  double get _total => redondear2(_importeLineas - _descuentoGlobal);

  double _enCarrito(CortePosDto corte) => _carrito
      .where((l) => l.corte.corteId == corte.corteId)
      .fold(0.0, (suma, l) => suma + l.cantidad);

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final token = await _auth.obtenerTokenVigente();
      final resultados = await Future.wait([_api.catalogo(token), _api.metodosPago(token)]);
      if (!mounted) return;
      setState(() {
        _catalogo = resultados[0] as List<CortePosDto>;
        _metodos = resultados[1] as List<MetodoPagoDto>;
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

  Future<void> _agregar(CortePosDto corte, VoidCallback refrescar) async {
    final disponible = corte.stockActual - _enCarrito(corte);
    final cantidad = await pedirCantidad(context, corte, disponible);

    if (cantidad == null) return;

    final existente = _carrito.where((l) => l.corte.corteId == corte.corteId).firstOrNull;
    setState(() {
      if (existente != null) {
        existente.cantidad = redondear3(existente.cantidad + cantidad);
      } else {
        _carrito.add(LineaCarrito(corte, cantidad));
      }
    });
    refrescar();
  }

  double redondear3(double v) => (v * 1000).roundToDouble() / 1000;

  Future<void> _cobrar() async {
    if (_carrito.isEmpty || _cobrando || _total <= 0) return;

    final resultado = await showDialog<ResultadoCobro>(
      context: context,
      builder: (_) => CobroDialog(total: _total, metodos: _metodos),
    );
    if (resultado == null) return;

    setState(() => _cobrando = true);
    try {
      final token = await _auth.obtenerTokenVigente();
      final venta = await _api.crearVenta(
        token,
        lineas: List.of(_carrito),
        pagos: resultado.pagos,
        descuentoTotal: _descuentoGlobal,
      );
      if (!mounted) return;
      setState(() {
        _carrito.clear();
        _descuentoTotalCaptura = null;
        _cobrando = false;
      });
      await _mostrarConfirmacion(venta, resultado.cambio);
      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cobrando = false);
      _avisar(e.mensaje);
      // 409: el stock cambio (otra caja vendio). Recargar para ver el stock real.
      if (e.statusCode == 409) await _cargar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cobrando = false);
      _avisar('No se pudo conectar con el servidor. La venta NO se registro.');
    }
  }

  Future<void> _mostrarConfirmacion(VentaDto venta, double cambio) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Venta #${venta.folio} registrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total: ${dinero(venta.total)}', style: Theme.of(context).textTheme.titleLarge),
              if (cambio > 0) ...[
                const SizedBox(height: 8),
                Text('Cambio: ${dinero(cambio)}', style: Theme.of(context).textTheme.titleLarge),
              ],
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ver ticket'),
              onPressed: () => verTicket(context, _api, venta.id),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Nueva venta')),
          ],
        ),
      );

  Widget _panelCatalogo() {
    final filtrados = _catalogo
        .where((c) => c.nombre.toLowerCase().contains(_filtro.toLowerCase()) ||
            c.tipoAnimal.toLowerCase().contains(_filtro.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar corte o animal',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _filtro = v),
          ),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? const Center(child: Text('Sin cortes para mostrar.'))
              : ListView.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final corte = filtrados[i];
                    final disponible = corte.stockActual - _enCarrito(corte);
                    final agotado = disponible <= 0;
                    return ListTile(
                      enabled: !agotado,
                      title: Text(corte.nombre),
                      subtitle: Text('${corte.tipoAnimal}  ·  ${dinero(corte.precioBase)}/${corte.unidadCorta}'),
                      trailing: Text(
                        agotado ? 'Agotado' : '${cantidadTexto(disponible)} ${corte.unidadCorta}',
                        style: TextStyle(color: agotado ? AppColors.stockAgotado : AppColors.stockNormal),
                      ),
                      onTap: () => _agregar(corte, () {}),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _descuentoDeLinea(LineaCarrito linea, VoidCallback? refrescar) async {
    final nuevo = await pedirDescuento(
      context,
      titulo: 'Descuento: ${linea.corte.nombre}',
      baseMonto: linea.bruto,
      actual: linea.descuentoCaptura,
    );
    if (nuevo == null) return;
    setState(() => linea.descuentoCaptura = nuevo.valor == 0 && !nuevo.porcentaje ? null : nuevo);
    refrescar?.call();
  }

  Future<void> _descuentoAlTotal(VoidCallback? refrescar) async {
    final nuevo = await pedirDescuento(
      context,
      titulo: 'Descuento al total',
      baseMonto: _importeLineas,
      actual: _descuentoTotalCaptura,
    );
    if (nuevo == null) return;
    setState(() => _descuentoTotalCaptura = nuevo.valor == 0 && !nuevo.porcentaje ? null : nuevo);
    refrescar?.call();
  }

  Widget _filaTotal(String etiqueta, String valor, {bool grande = false, Color? color}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: TextStyle(fontSize: grande ? 18 : 14, fontWeight: grande ? FontWeight.bold : FontWeight.normal, color: color)),
          Text(valor,
              style: TextStyle(fontSize: grande ? 24 : 14, fontWeight: grande ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      );

  Widget _panelCarrito({VoidCallback? refrescar}) {
    return Column(
      children: [
        Expanded(
          child: _carrito.isEmpty
              ? const Center(child: Text('El ticket esta vacio.\nToca un corte para agregarlo.', textAlign: TextAlign.center))
              : ListView.separated(
                  itemCount: _carrito.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final linea = _carrito[i];
                    return ListTile(
                      title: Text(linea.corte.nombre),
                      subtitle: Text(
                        '${cantidadTexto(linea.cantidad)} ${linea.corte.unidadCorta} × ${dinero(linea.corte.precioBase)}'
                        '${linea.descuento > 0 ? '\nDescuento ${linea.descuentoCaptura!.etiqueta}: -${dinero(linea.descuento)}' : ''}',
                      ),
                      isThreeLine: linea.descuento > 0,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dinero(linea.importe), style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (_puedeDescuento)
                            IconButton(
                              tooltip: 'Descuento',
                              icon: Icon(Icons.local_offer_outlined,
                                  color: linea.descuento > 0 ? AppColors.bronce : null),
                              onPressed: () => _descuentoDeLinea(linea, refrescar),
                            ),
                          IconButton(
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() => _carrito.removeAt(i));
                              refrescar?.call();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: AppColors.hueso),
          child: Column(
            children: [
              if (_descuentoTotal > 0) ...[
                _filaTotal('Subtotal', dinero(_subtotalBruto)),
                _filaTotal(
                  _descuentoTotalCaptura != null && _descuentoGlobal > 0
                      ? 'Descuento (${_descuentoTotalCaptura!.etiqueta} al total)'
                      : 'Descuento',
                  '-${dinero(_descuentoTotal)}',
                  color: AppColors.stockAgotado,
                ),
                const SizedBox(height: 4),
              ],
              _filaTotal('TOTAL', dinero(_total), grande: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _carrito.isEmpty || _cobrando || _total <= 0
                      ? null
                      : () {
                          // Cierra la hoja del ticket (si esta abierta) antes de cobrar.
                          if (refrescar != null) Navigator.of(context).pop();
                          _cobrar();
                        },
                  icon: _cobrando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.payments_outlined),
                  label: const Text('Cobrar'),
                ),
              ),
              if (_carrito.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (_puedeDescuento)
                      TextButton.icon(
                        onPressed: () => _descuentoAlTotal(refrescar),
                        icon: const Icon(Icons.local_offer_outlined),
                        label: Text(_descuentoTotalCaptura == null ? 'Descuento al total' : 'Cambiar descuento al total'),
                      ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _carrito.clear();
                          _descuentoTotalCaptura = null;
                        });
                        refrescar?.call();
                      },
                      child: const Text('Vaciar ticket'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _abrirTicketMovil() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: _panelCarrito(refrescar: () => setSheetState(() {})),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de venta'),
        actions: [
          IconButton(
            tooltip: 'Ventas del dia',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VentasScreen()),
            ),
          ),
          IconButton(tooltip: 'Actualizar stock', icon: const Icon(Icons.refresh), onPressed: _cargar),
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 800) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: _panelCatalogo()),
                          const VerticalDivider(width: 1),
                          Expanded(flex: 2, child: _panelCarrito()),
                        ],
                      );
                    }
                    return _panelCatalogo();
                  },
                ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800 || _cargando || _error != null) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _carrito.isEmpty ? null : _abrirTicketMovil,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text('Ticket (${_carrito.length}) · ${dinero(_total)}'),
              ),
            ),
          );
        },
      ),
    );
  }
}
