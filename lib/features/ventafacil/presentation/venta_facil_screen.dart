import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalogos/data/catalogo_api.dart';
import '../../catalogos/data/catalogo_dtos.dart';
import '../../pos/data/pos_dtos.dart' show dinero;
import '../data/venta_facil_api.dart';
import '../data/venta_facil_dtos.dart';
import 'rendimientos_screen.dart';

/// Venta Facil: se registra un animal (tipo, peso, costo), se ve el reparto
/// estimado por corte y, al confirmar, entra al inventario para vender ya.
class VentaFacilScreen extends StatefulWidget {
  const VentaFacilScreen({super.key});

  @override
  State<VentaFacilScreen> createState() => _VentaFacilScreenState();
}

class _VentaFacilScreenState extends State<VentaFacilScreen> {
  final _api = VentaFacilApi(ApiClient());
  final _catalogo = CatalogoApi(ApiClient());
  final _pesoCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();

  late AuthProvider _auth;
  String get _token => _auth.accessToken!;

  List<TipoAnimalDto> _tipos = [];
  List<LoteDto> _lotes = [];
  String? _tipoId;
  RendimientosDto? _cortes;                       // cortes por peso del tipo + lo aprendido
  final Map<String, TextEditingController> _kgCtrls = {};
  bool _pesar = true;                             // capturar los kilos reales de cada corte
  RepartoDto? _reparto;
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
    _pesoCtrl.dispose();
    _costoCtrl.dispose();
    _limpiarKg();
    super.dispose();
  }

  void _limpiarKg() {
    for (final c in _kgCtrls.values) {
      c.dispose();
    }
    _kgCtrls.clear();
  }

  /// Carga los cortes del tipo elegido y decide si hace falta pesar:
  /// con suficientes lotes pesados el sistema ya estima solo.
  Future<void> _cargarCortes() async {
    final id = _tipoId;
    if (id == null) return;
    try {
      final datos = await _api.cortes(_token, id);
      if (!mounted || _tipoId != id) return;
      _limpiarKg();
      for (final c in datos.cortes) {
        _kgCtrls[c.corteId] = TextEditingController();
      }
      setState(() {
        _cortes = datos;
        _pesar = !datos.usaAprendido;
        _reparto = null;
      });
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    }
  }

  Map<String, double>? _kgCapturados() => _pesar ? kgDeTextos({for (final e in _kgCtrls.entries) e.key: e.value.text}) : <String, double>{};

  bool get _puedeConfigurar => _auth.usuarioActual?.tienePermiso('catalogo.administrar') ?? false;

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final tipos = await _catalogo.listarTiposAnimal(_token);
      final lotes = await _api.lotes(_token);
      if (!mounted) return;
      setState(() {
        _tipos = tipos;
        _lotes = lotes;
        _tipoId ??= tipos.isEmpty ? null : tipos.first.id;
        _cargando = false;
      });
      await _cargarCortes();
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

  /// Lee peso y costo; muestra el motivo y devuelve null si no son validos.
  ({double peso, double costo})? _leerDatos() {
    final peso = parsearDecimal(_pesoCtrl.text);
    final costo = parsearDecimal(_costoCtrl.text);
    String? problema;
    if (_tipoId == null) {
      problema = 'Elige el tipo de animal.';
    } else if (peso == null || peso <= 0) {
      problema = 'Escribe el peso del animal en kg.';
    } else if (costo == null || costo < 0) {
      problema = 'Escribe cuanto costo el animal.';
    }
    final kgs = _kgCapturados();
    if (problema == null && kgs == null) {
      problema = 'Revisa los kilos de los cortes: deben ser numeros positivos.';
    } else if (problema == null && _pesar && kgs!.isEmpty) {
      problema = 'Captura los kilos de al menos un corte, o desactiva "Pesar cortes".';
    } else if (problema == null && _pesar && kgs!.values.fold(0.0, (a, b) => a + b) > peso!) {
      problema = 'Los cortes suman mas que el peso del animal.';
    }
    if (problema != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problema)));
      return null;
    }
    return (peso: peso!, costo: costo!);
  }

  Future<void> _calcular() async {
    final datos = _leerDatos();
    if (datos == null) return;
    setState(() => _trabajando = true);
    try {
      final reparto = await _api.previsualizar(_token, _tipoId!, datos.peso, datos.costo, kgPorCorte: _kgCapturados());
      if (!mounted) return;
      setState(() => _reparto = reparto);
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _registrar() async {
    final datos = _leerDatos();
    final reparto = _reparto;
    if (datos == null || reparto == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar lote'),
        content: Text(
          'Se agregaran ${reparto.kgAsignados.toStringAsFixed(3)} kg de '
          '${reparto.tipoAnimalNombre} al inventario.\n\n${reparto.esEstimado ? 'El reparto es una estimacion; se puede corregir despues con un ajuste de inventario.' : 'Los kilos son los que pesaste; el sistema los usara para aprender el rendimiento.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _trabajando = true);
    try {
      await _api.registrarLote(_token, _tipoId!, datos.peso, datos.costo, kgPorCorte: _kgCapturados());
      _pesoCtrl.clear();
      _costoCtrl.clear();
      for (final c in _kgCtrls.values) {
        c.clear();
      }
      if (!mounted) return;
      setState(() => _reparto = null);
      _avisar('Lote registrado; el inventario ya esta actualizado.');
      await _cargar();
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirRendimientos() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RendimientosScreen(tipoInicialId: _tipoId)));
    if (mounted) setState(() => _reparto = null); // los porcentajes pudieron cambiar
  }

  Widget _seccionPesar() {
    final cortes = _cortes!;
    final suma = _kgCapturados()?.values.fold(0.0, (a, b) => a + b) ?? 0.0;
    final peso = parsearDecimal(_pesoCtrl.text);
    final mensaje = cortes.usaAprendido
        ? 'El sistema ya conoce el rendimiento (${cortes.lotesMedidos} lotes pesados): no necesitas pesar. '
            'Si quieres, puedes pesar este animal para afinar los datos.'
        : 'Aun estoy aprendiendo (${cortes.lotesMedidos} de ${cortes.lotesParaAprender} lotes pesados). '
            'Pesa los cortes de este animal; despues de ${cortes.lotesParaAprender} lotes el sistema estimara solo.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pesar cortes (kg reales)'),
              value: _pesar,
              onChanged: (v) => setState(() {
                _pesar = v;
                _reparto = null;
              }),
            ),
            if (_pesar) ...[
              for (final c in cortes.cortes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.corteNombre)),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _kgCtrls[c.corteId],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(suffixText: 'kg', border: OutlineInputBorder(), isDense: true),
                          onChanged: (_) => setState(() => _reparto = null),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Suma: ${suma.toStringAsFixed(3)} kg'
                '${peso != null ? '  -  Hueso / merma: ${(peso - suma).toStringAsFixed(3)} kg' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (peso != null && suma > peso) ? Colors.red.shade700 : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Venta Facil'),
        actions: [
          if (_puedeConfigurar)
            IconButton(
              tooltip: 'Rendimientos por corte',
              icon: const Icon(Icons.tune),
              onPressed: _abrirRendimientos,
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      value: _tipoId,
                      decoration: const InputDecoration(labelText: 'Tipo de animal', border: OutlineInputBorder()),
                      items: [for (final t in _tipos) DropdownMenuItem(value: t.id, child: Text(t.nombre))],
                      onChanged: (v) {
                        setState(() {
                          _tipoId = v;
                          _reparto = null;
                          _cortes = null;
                        });
                        _cargarCortes();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() => _reparto = null),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _costoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Costo de compra (\$)', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() => _reparto = null),
                    ),
                    const SizedBox(height: 12),
                    if (_cortes != null) ...[_seccionPesar(), const SizedBox(height: 12)],
                    FilledButton.icon(
                      onPressed: _trabajando ? null : _calcular,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Calcular reparto'),
                    ),
                    if (_reparto != null) ...[
                      const SizedBox(height: 16),
                      _RepartoCard(reparto: _reparto!),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _trabajando ? null : _registrar,
                        icon: const Icon(Icons.check),
                        label: const Text('Registrar lote e ingresar a inventario'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('Lotes recientes', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_lotes.isEmpty) const Text('Todavia no hay lotes registrados.'),
                    for (final l in _lotes)
                      Card(
                        child: ListTile(
                          title: Text('${l.tipoAnimalNombre} - ${l.pesoKg.toStringAsFixed(1)} kg'),
                          subtitle: Text(
                            '${l.fechaCompra.day.toString().padLeft(2, '0')}/'
                            '${l.fechaCompra.month.toString().padLeft(2, '0')}/${l.fechaCompra.year}'
                            ' - costo ${dinero(l.precioCompra)} (${dinero(l.costoPorKg)}/kg)'
                            '${l.esEstimado ? ' - estimado' : ' - pesado'}',
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _RepartoCard extends StatelessWidget {
  final RepartoDto reparto;

  const _RepartoCard({required this.reparto});

  @override
  Widget build(BuildContext context) {
    final utilidadPositiva = reparto.utilidadEstimada >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reparto.esEstimado ? 'Reparto estimado de ${reparto.tipoAnimalNombre}' : 'Reparto pesado de ${reparto.tipoAnimalNombre}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              switch (reparto.origen) {
                'Aprendido' => 'Calculado con lo aprendido de ${reparto.lotesMedidos} lotes pesados',
                'Pesado' => 'Con los kilos que capturaste',
                _ => 'Calculado con los porcentajes configurados a mano',
              },
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (final l in reparto.lineas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${l.corteNombre} (${l.porcentaje.toStringAsFixed(l.porcentaje % 1 == 0 ? 0 : 2)}%)')),
                    Text('${l.kgEstimados.toStringAsFixed(3)} kg'),
                    SizedBox(width: 90, child: Text(dinero(l.ventaEstimada), textAlign: TextAlign.right)),
                  ],
                ),
              ),
            const Divider(),
            Text('Hueso / merma: ${reparto.kgMerma.toStringAsFixed(3)} kg'),
            Text('Costo por kg del animal: ${dinero(reparto.costoPorKg)}'),
            Text('Venta ${reparto.esEstimado ? 'estimada' : ''} a precio base: ${dinero(reparto.ventaEstimadaTotal)}'),
            Text(
              'Utilidad ${reparto.esEstimado ? 'estimada' : ''}: ${dinero(reparto.utilidadEstimada)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: utilidadPositiva ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
