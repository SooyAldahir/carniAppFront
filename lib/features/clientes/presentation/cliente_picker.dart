import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pos/data/pos_dtos.dart';
import '../data/clientes_api.dart';
import '../data/clientes_dtos.dart';

/// Resultado del selector: [cliente] null significa "venta de mostrador" (sin cliente).
class SeleccionCliente {
  final ClienteDto? cliente;
  const SeleccionCliente(this.cliente);
}

/// Devuelve null si se cancela el dialogo (no cambia nada).
Future<SeleccionCliente?> elegirCliente(BuildContext context) =>
    showDialog<SeleccionCliente>(context: context, builder: (_) => const _ClientePickerDialog());

class _ClientePickerDialog extends StatefulWidget {
  const _ClientePickerDialog();

  @override
  State<_ClientePickerDialog> createState() => _ClientePickerDialogState();
}

class _ClientePickerDialogState extends State<_ClientePickerDialog> {
  final ClientesApi _api = ClientesApi(ApiClient());
  List<ClienteDto> _clientes = [];
  String _filtro = '';
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final token = await context.read<AuthProvider>().obtenerTokenVigente();
      final lista = await _api.listar(token);
      if (mounted) setState(() {
        _clientes = lista;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'No se pudieron cargar los clientes.';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _clientes
        .where((c) =>
            c.nombre.toLowerCase().contains(_filtro.toLowerCase()) || (c.telefono ?? '').contains(_filtro.trim()))
        .toList();

    return AlertDialog(
      title: const Text('Cliente de la venta'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre o telefono',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : filtrados.isEmpty
                          ? const Center(child: Text('Sin resultados.'))
                          : ListView.builder(
                              itemCount: filtrados.length,
                              itemBuilder: (context, i) {
                                final c = filtrados[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(c.nombre),
                                  subtitle: Text(c.limiteCredito > 0
                                      ? 'Credito disponible: ${dinero(c.creditoDisponible)}'
                                      : 'Sin credito'),
                                  trailing: c.tieneSaldo
                                      ? Text('Debe ${dinero(c.saldoCredito)}', style: const TextStyle(color: Colors.red))
                                      : null,
                                  onTap: () => Navigator.pop(context, SeleccionCliente(c)),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, const SeleccionCliente(null)), child: const Text('Venta de mostrador')),
      ],
    );
  }
}
