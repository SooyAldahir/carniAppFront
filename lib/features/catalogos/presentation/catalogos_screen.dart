import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/catalogo_api.dart';
import '../data/catalogo_dtos.dart';

/// RF-INV-001/002, RF-CONFIG-002: pantalla de administracion del
/// catalogo (tipos de animal y cortes). Las acciones de escritura se
/// ocultan si el usuario no tiene el permiso 'catalogo.administrar'.
class CatalogosScreen extends StatefulWidget {
  const CatalogosScreen({super.key});

  @override
  State<CatalogosScreen> createState() => _CatalogosScreenState();
}

class _CatalogosScreenState extends State<CatalogosScreen> with SingleTickerProviderStateMixin {
  final CatalogoApi _api = CatalogoApi(ApiClient());
  late TabController _tabController;

  List<TipoAnimalDto> _tiposAnimal = [];
  List<CorteDto> _cortes = [];
  bool _cargando = true;
  String? _error;

  late String _token;
  late bool _puedeAdministrar;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final auth = context.read<AuthProvider>();
    _token = auth.accessToken!;
    _puedeAdministrar = auth.usuarioActual?.tienePermiso('catalogo.administrar') ?? false;
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final tipos = await _api.listarTiposAnimal(_token);
      final cortes = await _api.listarCortes(_token);
      setState(() {
        _tiposAnimal = tipos;
        _cortes = cortes;
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

  Future<void> _manejarError(Future<void> Function() accion) async {
    try {
      await accion();
      await _cargarTodo();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
    }
  }

  Future<void> _abrirDialogoTipoAnimal({TipoAnimalDto? existente}) async {
    final controller = TextEditingController(text: existente?.nombre ?? '');
    final formKey = GlobalKey<FormState>();

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existente == null ? 'Nuevo tipo de animal' : 'Editar tipo de animal'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nombre'),
            autofocus: true,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardar != true) return;

    await _manejarError(() => existente == null
        ? _api.crearTipoAnimal(_token, controller.text.trim())
        : _api.actualizarTipoAnimal(_token, existente.id, controller.text.trim()));
  }

  Future<void> _confirmarDesactivarTipoAnimal(TipoAnimalDto tipo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar tipo de animal'),
        content: Text('¿Desactivar "${tipo.nombre}"? No se podra usar en cortes nuevos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desactivar')),
        ],
      ),
    );

    if (confirmar == true) {
      await _manejarError(() => _api.desactivarTipoAnimal(_token, tipo.id));
    }
  }

  Future<void> _abrirDialogoCorte({CorteDto? existente}) async {
    if (_tiposAnimal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero da de alta al menos un tipo de animal.')),
      );
      return;
    }

    final nombreController = TextEditingController(text: existente?.nombre ?? '');
    final precioController =
        TextEditingController(text: existente != null ? existente.precioBase.toString() : '');
    final stockMinimoController =
        TextEditingController(text: existente != null ? existente.stockMinimo.toString() : '0');
    String tipoAnimalId = existente?.tipoAnimalId ?? _tiposAnimal.first.id;
    String unidadVenta = existente?.unidadVenta ?? 'Peso';
    final formKey = GlobalKey<FormState>();

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existente == null ? 'Nuevo corte' : 'Editar corte'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tipoAnimalId,
                    decoration: const InputDecoration(labelText: 'Tipo de animal'),
                    items: _tiposAnimal
                        .map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombre)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => tipoAnimalId = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre del corte'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unidadVenta,
                    decoration: const InputDecoration(labelText: 'Unidad de venta'),
                    items: const [
                      DropdownMenuItem(value: 'Peso', child: Text('Peso (kg)')),
                      DropdownMenuItem(value: 'Pieza', child: Text('Pieza')),
                    ],
                    onChanged: (v) => setDialogState(() => unidadVenta = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: precioController,
                    decoration: const InputDecoration(labelText: 'Precio base (MXN)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final valor = double.tryParse(v ?? '');
                      return (valor == null || valor <= 0) ? 'Precio invalido' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockMinimoController,
                    decoration: const InputDecoration(labelText: 'Stock minimo de alerta'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final valor = double.tryParse(v ?? '');
                      return (valor == null || valor < 0) ? 'Valor invalido' : null;
                    },
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardar != true) return;

    final precio = double.parse(precioController.text);
    final stockMinimo = double.parse(stockMinimoController.text);
    final nombre = nombreController.text.trim();

    await _manejarError(() => existente == null
        ? _api.crearCorte(
            _token,
            tipoAnimalId: tipoAnimalId,
            nombre: nombre,
            unidadVenta: unidadVenta,
            precioBase: precio,
            stockMinimo: stockMinimo,
          )
        : _api.actualizarCorte(
            _token,
            existente.id,
            tipoAnimalId: tipoAnimalId,
            nombre: nombre,
            unidadVenta: unidadVenta,
            precioBase: precio,
            stockMinimo: stockMinimo,
          ));
  }

  Future<void> _confirmarDesactivarCorte(CorteDto corte) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar corte'),
        content: Text('¿Desactivar "${corte.nombre}"? Ya no aparecera disponible para la venta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desactivar')),
        ],
      ),
    );

    if (confirmar == true) {
      await _manejarError(() => _api.desactivarCorte(_token, corte.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tipos de animal'),
            Tab(text: 'Cortes'),
          ],
        ),
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
                      FilledButton(onPressed: _cargarTodo, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [_buildTiposAnimal(), _buildCortes()],
                ),
      floatingActionButton: _puedeAdministrar
          ? FloatingActionButton(
              onPressed: () => _tabController.index == 0
                  ? _abrirDialogoTipoAnimal()
                  : _abrirDialogoCorte(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTiposAnimal() {
    if (_tiposAnimal.isEmpty) {
      return const Center(child: Text('Todavia no hay tipos de animal registrados.'));
    }

    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView.builder(
        itemCount: _tiposAnimal.length,
        itemBuilder: (context, index) {
          final tipo = _tiposAnimal[index];
          return ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(tipo.nombre),
            subtitle: Text('${tipo.cantidadCortes} corte(s) activo(s)'),
            trailing: _puedeAdministrar
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _abrirDialogoTipoAnimal(existente: tipo),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmarDesactivarTipoAnimal(tipo),
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildCortes() {
    if (_cortes.isEmpty) {
      return const Center(child: Text('Todavia no hay cortes registrados.'));
    }

    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView.builder(
        itemCount: _cortes.length,
        itemBuilder: (context, index) {
          final corte = _cortes[index];
          final unidad = corte.unidadVenta == 'Peso' ? 'kg' : 'pieza';
          return ListTile(
            leading: const Icon(Icons.content_cut),
            title: Text(corte.nombre),
            subtitle: Text(
              '${corte.tipoAnimalNombre} · \$${corte.precioBase.toStringAsFixed(2)}/$unidad'
              ' · minimo: ${corte.stockMinimo}',
            ),
            trailing: _puedeAdministrar
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _abrirDialogoCorte(existente: corte),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmarDesactivarCorte(corte),
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }
}
