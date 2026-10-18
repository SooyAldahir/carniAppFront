import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalogos/data/catalogo_api.dart';
import '../../catalogos/data/catalogo_dtos.dart';
import '../data/venta_facil_api.dart';
import '../data/venta_facil_dtos.dart';

/// Configura que % del peso del animal rinde cada corte (solo cortes por peso).
/// La suma no puede pasar de 100%; el resto es hueso/merma.
class RendimientosScreen extends StatefulWidget {
  final String? tipoInicialId;

  const RendimientosScreen({super.key, this.tipoInicialId});

  @override
  State<RendimientosScreen> createState() => _RendimientosScreenState();
}

class _RendimientosScreenState extends State<RendimientosScreen> {
  final _api = VentaFacilApi(ApiClient());
  final _catalogo = CatalogoApi(ApiClient());
  final Map<String, TextEditingController> _ctrls = {};

  late AuthProvider _auth;
  String get _token => _auth.accessToken!;

  List<TipoAnimalDto> _tipos = [];
  RendimientosDto? _datos;
  String? _tipoId;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _tipoId = widget.tipoInicialId;
    _inicializar();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _inicializar() async {
    try {
      final tipos = await _catalogo.listarTiposAnimal(_token);
      if (!mounted) return;
      _tipos = tipos;
      _tipoId ??= tipos.isEmpty ? null : tipos.first.id;
      await _cargarTipo();
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

  Future<void> _cargarTipo() async {
    final id = _tipoId;
    if (id == null) {
      setState(() => _cargando = false);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _api.rendimientos(_token, id);
      if (!mounted) return;
      for (final c in _ctrls.values) {
        c.dispose();
      }
      _ctrls.clear();
      for (final item in datos.cortes) {
        final p = item.porcentaje;
        _ctrls[item.corteId] = TextEditingController(text: p == null ? '' : (p % 1 == 0 ? p.toStringAsFixed(0) : p.toString()));
      }
      setState(() {
        _datos = datos;
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

  double get _suma => sumaPorcentajes(_ctrls.values.map((c) => c.text));

  Future<void> _guardar() async {
    final porcentajes = <String, double?>{};
    for (final e in _ctrls.entries) {
      final texto = e.value.text.trim();
      if (texto.isEmpty) {
        porcentajes[e.key] = null;
        continue;
      }
      final v = parsearDecimal(texto);
      if (v == null || v < 0 || v > 100) {
        _avisar('Cada porcentaje debe estar entre 0 y 100.');
        return;
      }
      porcentajes[e.key] = v;
    }
    if (_suma > 100) {
      _avisar('Los porcentajes suman ${_suma.toStringAsFixed(2)}%; no pueden pasar de 100%.');
      return;
    }

    setState(() => _guardando = true);
    try {
      await _api.guardarRendimientos(_token, _tipoId!, porcentajes);
      _avisar('Rendimientos guardados.');
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final suma = _suma;
    final excede = suma > 100;
    return Scaffold(
      appBar: AppBar(title: const Text('Rendimientos por corte')),
      body: _error != null
          ? Center(child: Text(_error!))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _tipoId,
                    decoration: const InputDecoration(labelText: 'Tipo de animal', border: OutlineInputBorder()),
                    items: [for (final t in _tipos) DropdownMenuItem(value: t.id, child: Text(t.nombre))],
                    onChanged: (v) {
                      setState(() => _tipoId = v);
                      _cargarTipo();
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _cargando
                        ? const Center(child: CircularProgressIndicator())
                        : (_datos == null || _datos!.cortes.isEmpty)
                            ? const Center(child: Text('Este tipo de animal no tiene cortes que se vendan por peso.'))
                            : ListView(
                                children: [
                                  for (final item in _datos!.cortes)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(item.corteNombre)),
                                          SizedBox(
                                            width: 110,
                                            child: TextField(
                                              controller: _ctrls[item.corteId],
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(suffixText: '%', border: OutlineInputBorder(), isDense: true),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suma: ${suma.toStringAsFixed(2)}%   -   Hueso / merma: ${(100 - suma).clamp(0, 100).toStringAsFixed(2)}%',
                    style: TextStyle(color: excede ? Colors.red.shade700 : null, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_guardando || excede || _datos == null || _datos!.cortes.isEmpty) ? null : _guardar,
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
