import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/inventario_api.dart';
import '../data/inventario_dtos.dart';
import 'kardex_screen.dart';

/// RF-INV-003/004/005/008: stock por corte con alertas de minimo, y
/// ajustes manuales (entrada/merma/ajuste) con motivo obligatorio.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final InventarioApi _api = InventarioApi(ApiClient());
  List<InventarioItemDto> _items = [];
  bool _cargando = true;
  String? _error;

  late AuthProvider _auth;

  /// Siempre el token mas reciente: AuthProvider lo renueva solo antes de que venza.
  String get _token => _auth.accessToken!;
  late bool _puedeAjustar;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _auth = auth;
    _puedeAjustar = auth.usuarioActual?.tienePermiso('inventario.ajustar') ?? false;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final items = await _api.listar(_token);
      setState(() {
        _items = items;
        _cargando = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo conectar con el servidor.';
        _cargando = false;
      });
    }
  }

  Future<void> _verKardex(InventarioItemDto item) async {
    try {
      final movimientos = await _api.kardex(_token, item.corteId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KardexScreen(corteNombre: item.corteNombre, movimientos: movimientos),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _abrirDialogoAjuste() async {
    if (_items.isEmpty) return;

    String corteId = _items.first.corteId;
    String tipoMovimiento = 'Entrada';
    final cantidadController = TextEditingController();
    final motivoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajuste de inventario'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: corteId,
                    decoration: const InputDecoration(labelText: 'Corte'),
                    items: _items
                        .map((i) => DropdownMenuItem(value: i.corteId, child: Text(i.corteNombre)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => corteId = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tipoMovimiento,
                    decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
                    items: const [
                      DropdownMenuItem(value: 'Entrada', child: Text('Entrada (sube stock)')),
                      DropdownMenuItem(value: 'Merma', child: Text('Merma (baja stock)')),
                      DropdownMenuItem(value: 'Ajuste', child: Text('Ajuste (corrige un error)')),
                    ],
                    onChanged: (v) => setDialogState(() => tipoMovimiento = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cantidadController,
                    decoration: InputDecoration(
                      labelText: tipoMovimiento == 'Entrada'
                          ? 'Cantidad a sumar'
                          : 'Cantidad a restar (positiva)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) {
                      final valor = double.tryParse(v ?? '');
                      return (valor == null || valor == 0) ? 'Cantidad invalida' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: motivoController,
                    decoration: const InputDecoration(labelText: 'Motivo (obligatorio)'),
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'El motivo es obligatorio' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    var cantidad = double.parse(cantidadController.text);
    // El usuario siempre captura una magnitud positiva; el signo lo
    // decide el tipo de movimiento (Entrada suma, Merma/Ajuste restan).
    if (tipoMovimiento != 'Entrada') cantidad = -cantidad.abs();
    else cantidad = cantidad.abs();

    try {
      await _api.ajustar(
        _token,
        corteId: corteId,
        tipoMovimiento: tipoMovimiento,
        cantidad: cantidad,
        motivo: motivoController.text.trim(),
      );
      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
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
              : _items.isEmpty
                  ? const Center(child: Text('Todavia no hay cortes en el catálogo.'))
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final unidad = item.unidadVenta == 'Peso' ? 'kg' : 'pza';
                          return ListTile(
                            leading: Icon(
                              item.enAlerta ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                              color: item.enAlerta ? AppColors.stockAgotado : AppColors.stockNormal,
                            ),
                            title: Text(item.corteNombre),
                            subtitle: Text(
                              'Stock: ${item.stockActual.toStringAsFixed(3)} $unidad'
                              ' · minimo: ${item.stockMinimo.toStringAsFixed(3)}',
                            ),
                            trailing: item.enAlerta
                                ? const Text('BAJO', style: TextStyle(color: AppColors.stockAgotado, fontWeight: FontWeight.bold))
                                : null,
                            onTap: () => _verKardex(item),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _puedeAjustar
          ? FloatingActionButton.extended(
              onPressed: _abrirDialogoAjuste,
              icon: const Icon(Icons.tune),
              label: const Text('Ajustar'),
            )
          : null,
    );
  }
}
