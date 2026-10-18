import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pos/data/pos_dtos.dart';
import '../data/clientes_api.dart';
import '../data/clientes_dtos.dart';

/// RF-CLI-001 y RF-CRED-001..003: alta/edicion de clientes, limite y saldo de
/// credito, y registro de abonos. Las acciones se muestran segun los permisos
/// 'clientes.administrar' y 'creditos.administrar'.
class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final ClientesApi _api = ClientesApi(ApiClient());
  late AuthProvider _auth;
  late bool _puedeAdministrar;
  late bool _puedeCobrar;

  List<ClienteDto> _clientes = [];
  String _filtro = '';
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    final usuario = _auth.usuarioActual;
    _puedeAdministrar = usuario?.tienePermiso('clientes.administrar') ?? false;
    _puedeCobrar = usuario?.tienePermiso('creditos.administrar') ?? false;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final token = await _auth.obtenerTokenVigente();
      final lista = await _api.listar(token);
      if (!mounted) return;
      setState(() {
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

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Ejecuta una accion contra la API mostrando el mensaje del servidor si falla.
  Future<bool> _ejecutar(Future<void> Function(String token) accion) async {
    try {
      final token = await _auth.obtenerTokenVigente();
      await accion(token);
      return true;
    } on ApiException catch (e) {
      _avisar(e.mensaje);
    } catch (_) {
      _avisar('No se pudo completar la operacion.');
    }
    return false;
  }

  Future<void> _nuevo() async {
    final datos = await showDialog<DatosCliente>(context: context, builder: (_) => const FormularioClienteDialog());
    if (datos == null) return;
    final ok = await _ejecutar((t) => _api.crear(t,
        nombre: datos.nombre,
        telefono: datos.telefono,
        direccion: datos.direccion,
        referencias: datos.referencias,
        limiteCredito: datos.limiteCredito));
    if (ok) await _cargar();
  }

  Future<void> _editar(ClienteDto cliente) async {
    final datos = await showDialog<DatosCliente>(context: context, builder: (_) => FormularioClienteDialog(existente: cliente));
    if (datos == null) return;
    final ok = await _ejecutar((t) => _api.actualizar(t, cliente.id,
        nombre: datos.nombre,
        telefono: datos.telefono,
        direccion: datos.direccion,
        referencias: datos.referencias,
        limiteCredito: datos.limiteCredito));
    if (ok) await _cargar();
  }

  Future<void> _darDeBaja(ClienteDto cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dar de baja'),
        content: Text('¿Dar de baja a "${cliente.nombre}"? Sus ventas anteriores se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Dar de baja')),
        ],
      ),
    );
    if (confirmar != true) return;
    final ok = await _ejecutar((t) => _api.desactivar(t, cliente.id));
    if (ok) await _cargar();
  }

  Future<void> _abonar(ClienteDto cliente) async {
    final importe = await showDialog<double>(context: context, builder: (_) => AbonoDialog(cliente: cliente));
    if (importe == null) return;
    final ok = await _ejecutar((t) => _api.abonar(t, cliente.id, importe));
    if (ok) {
      _avisar('Abono de ${dinero(importe)} registrado.');
      await _cargar();
    }
  }

  Future<void> _abrirDetalle(ClienteDto cliente) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DetalleClienteDialog(
        cliente: cliente,
        api: _api,
        auth: _auth,
        puedeAdministrar: _puedeAdministrar,
        puedeCobrar: _puedeCobrar,
        alEditar: () => _editar(cliente),
        alAbonar: () => _abonar(cliente),
        alDarDeBaja: () => _darDeBaja(cliente),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _clientes
        .where((c) =>
            c.nombre.toLowerCase().contains(_filtro.toLowerCase()) || (c.telefono ?? '').contains(_filtro.trim()))
        .toList();
    final totalPorCobrar = _clientes.fold<double>(0, (s, c) => s + c.saldoCredito);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [IconButton(tooltip: 'Actualizar', onPressed: _cargar, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: _puedeAdministrar
          ? FloatingActionButton.extended(onPressed: _nuevo, icon: const Icon(Icons.person_add), label: const Text('Nuevo cliente'))
          : null,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                  ]),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar por nombre o telefono',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _filtro = v),
                      ),
                    ),
                    if (totalPorCobrar > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Por cobrar en total: ${dinero(totalPorCobrar)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    Expanded(
                      child: filtrados.isEmpty
                          ? const Center(child: Text('Sin clientes para mostrar.'))
                          : ListView.separated(
                              itemCount: filtrados.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = filtrados[i];
                                return ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(c.nombre),
                                  subtitle: Text(c.telefono ?? 'Sin telefono'),
                                  trailing: c.tieneSaldo
                                      ? Text('Debe ${dinero(c.saldoCredito)}',
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                                      : (c.limiteCredito > 0
                                          ? Text('Credito ${dinero(c.limiteCredito)}', style: const TextStyle(color: Colors.grey))
                                          : null),
                                  onTap: () => _abrirDetalle(c),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class DatosCliente {
  final String nombre;
  final String? telefono;
  final String? direccion;
  final String? referencias;
  final double limiteCredito;

  DatosCliente({required this.nombre, this.telefono, this.direccion, this.referencias, required this.limiteCredito});
}

/// Alta/edicion. Los controllers viven en el State (se liberan en dispose()).
class FormularioClienteDialog extends StatefulWidget {
  final ClienteDto? existente;

  const FormularioClienteDialog({super.key, this.existente});

  @override
  State<FormularioClienteDialog> createState() => _FormularioClienteDialogState();
}

class _FormularioClienteDialogState extends State<FormularioClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;
  late final TextEditingController _referencias;
  late final TextEditingController _limite;

  @override
  void initState() {
    super.initState();
    final c = widget.existente;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _direccion = TextEditingController(text: c?.direccion ?? '');
    _referencias = TextEditingController(text: c?.referencias ?? '');
    _limite = TextEditingController(text: c != null ? c.limiteCredito.toStringAsFixed(2) : '0');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _referencias.dispose();
    _limite.dispose();
    super.dispose();
  }

  String? _opcional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Nuevo cliente' : 'Editar cliente'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefono (opcional)'),
                ),
                TextFormField(controller: _direccion, decoration: const InputDecoration(labelText: 'Direccion (opcional)')),
                TextFormField(controller: _referencias, decoration: const InputDecoration(labelText: 'Referencias (opcional)')),
                TextFormField(
                  controller: _limite,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Limite de credito (MXN)',
                    helperText: '0 = no se le fia',
                    prefixText: '\$ ',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return (n == null || n < 0) ? 'Monto invalido' : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              DatosCliente(
                nombre: _nombre.text.trim(),
                telefono: _opcional(_telefono),
                direccion: _opcional(_direccion),
                referencias: _opcional(_referencias),
                limiteCredito: double.parse(_limite.text),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// RF-CRED-002/003: captura de un abono (no puede exceder el saldo).
class AbonoDialog extends StatefulWidget {
  final ClienteDto cliente;

  const AbonoDialog({super.key, required this.cliente});

  @override
  State<AbonoDialog> createState() => _AbonoDialogState();
}

class _AbonoDialogState extends State<AbonoDialog> {
  late final TextEditingController _importe;
  String? _error;

  @override
  void initState() {
    super.initState();
    _importe = TextEditingController();
  }

  @override
  void dispose() {
    _importe.dispose();
    super.dispose();
  }

  void _aceptar() {
    final valor = double.tryParse(_importe.text.trim());
    if (valor == null || valor <= 0) {
      setState(() => _error = 'Escribe un monto mayor a cero.');
      return;
    }
    final importe = redondear2(valor);
    if (importe > widget.cliente.saldoCredito) {
      setState(() => _error = 'Es mayor al saldo (${dinero(widget.cliente.saldoCredito)}).');
      return;
    }
    Navigator.pop(context, importe);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Abono de ${widget.cliente.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Debe: ${dinero(widget.cliente.saldoCredito)}'),
          const SizedBox(height: 8),
          TextField(
            controller: _importe,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Importe del abono', prefixText: '\$ ', errorText: _error),
            onSubmitted: (_) => _aceptar(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _importe.text = widget.cliente.saldoCredito.toStringAsFixed(2)),
              child: const Text('Liquidar todo'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _aceptar, child: const Text('Registrar abono')),
      ],
    );
  }
}

class _DetalleClienteDialog extends StatefulWidget {
  final ClienteDto cliente;
  final ClientesApi api;
  final AuthProvider auth;
  final bool puedeAdministrar;
  final bool puedeCobrar;
  final Future<void> Function() alEditar;
  final Future<void> Function() alAbonar;
  final Future<void> Function() alDarDeBaja;

  const _DetalleClienteDialog({
    required this.cliente,
    required this.api,
    required this.auth,
    required this.puedeAdministrar,
    required this.puedeCobrar,
    required this.alEditar,
    required this.alAbonar,
    required this.alDarDeBaja,
  });

  @override
  State<_DetalleClienteDialog> createState() => _DetalleClienteDialogState();
}

class _DetalleClienteDialogState extends State<_DetalleClienteDialog> {
  List<AbonoDto>? _abonos;
  String? _errorAbonos;

  @override
  void initState() {
    super.initState();
    if (widget.puedeCobrar) _cargarAbonos();
  }

  Future<void> _cargarAbonos() async {
    try {
      final token = await widget.auth.obtenerTokenVigente();
      final lista = await widget.api.abonos(token, widget.cliente.id);
      if (mounted) setState(() => _abonos = lista);
    } catch (_) {
      if (mounted) setState(() => _errorAbonos = 'No se pudieron cargar los abonos.');
    }
  }

  /// Cierra el detalle y luego corre la accion (que abre su propio dialogo).
  void _y(Future<void> Function() accion) {
    Navigator.pop(context);
    accion();
  }

  String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    return AlertDialog(
      title: Text(c.nombre),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.telefono != null) Text('Tel: ${c.telefono}'),
              if (c.direccion != null) Text('Direccion: ${c.direccion}'),
              if (c.referencias != null) Text('Referencias: ${c.referencias}'),
              const Divider(),
              Text('Limite de credito: ${dinero(c.limiteCredito)}'),
              Text('Saldo (debe): ${dinero(c.saldoCredito)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: c.tieneSaldo ? Colors.red : null)),
              Text('Disponible: ${dinero(c.creditoDisponible)}'),
              if (widget.puedeCobrar) ...[
                const Divider(),
                const Text('Abonos', style: TextStyle(fontWeight: FontWeight.bold)),
                if (_errorAbonos != null)
                  Text(_errorAbonos!)
                else if (_abonos == null)
                  const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
                else if (_abonos!.isEmpty)
                  const Text('Sin abonos registrados.')
                else
                  for (final a in _abonos!.take(10))
                    Text('${_fecha(a.fecha)}  ·  ${dinero(a.importe)}${a.usuarioNombre != null ? '  ·  ${a.usuarioNombre}' : ''}'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.puedeAdministrar) TextButton(onPressed: () => _y(widget.alDarDeBaja), child: const Text('Dar de baja')),
        if (widget.puedeAdministrar) TextButton(onPressed: () => _y(widget.alEditar), child: const Text('Editar')),
        if (widget.puedeCobrar && c.tieneSaldo)
          FilledButton(onPressed: () => _y(widget.alAbonar), child: const Text('Abonar')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}
