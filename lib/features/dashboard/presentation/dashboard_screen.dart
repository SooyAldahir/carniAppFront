import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../negocio/data/negocio_api.dart';
import '../../negocio/data/negocio_dto.dart';

/// Dashboard minimo de Sprint 1: muestra la marca del negocio
/// (RF-CONFIG-003) y los datos de sesion del usuario autenticado. Los
/// modulos reales (POS, Inventario, etc.) llegan en sprints posteriores.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NegocioApi _negocioApi = NegocioApi(ApiClient());
  late Future<NegocioDto> _negocioFuture;

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthProvider>().accessToken!;
    _negocioFuture = _negocioApi.obtener(token);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuarioActual!;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<NegocioDto>(
          future: _negocioFuture,
          builder: (context, snapshot) => Text(
            snapshot.data?.nombreComercial ?? 'CarniApp',
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.vino,
                child: Text(
                  usuario.nombreCompleto.isNotEmpty
                      ? usuario.nombreCompleto[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hola, ${usuario.nombreCompleto}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                usuario.rol,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sprint 1 completo: login, permisos y configuracion del '
                'negocio funcionando de punta a punta.\n\n'
                'Los modulos (POS, Inventario, Clientes...) llegan en los '
                'siguientes sprints.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
