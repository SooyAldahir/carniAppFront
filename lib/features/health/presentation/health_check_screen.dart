import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../data/health_status.dart';

/// Pantalla de verificacion del Sprint 0: confirma que la app Flutter,
/// el backend ASP.NET Core y SQL Server estan conectados de punta a
/// punta. Es intencionalmente simple -- no es una pantalla final de
/// producto, es la prueba de que la tuberia completa funciona antes
/// de construir el resto de los modulos (Sprints 1 en adelante).
class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key});

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  final ApiClient _apiClient = ApiClient();

  late Future<HealthStatus> _healthFuture;

  @override
  void initState() {
    super.initState();
    _healthFuture = _fetchHealth();
  }

  Future<HealthStatus> _fetchHealth() async {
    final json = await _apiClient.getJson('/api/health');
    return HealthStatus.fromJson(json);
  }

  void _reintentar() {
    setState(() {
      _healthFuture = _fetchHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CarniApp · Sprint 0')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<HealthStatus>(
            future: _healthFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error.toString());
              }

              final status = snapshot.data!;
              return _buildStatus(status);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(String mensaje) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off, size: 48, color: AppColors.stockAgotado),
        const SizedBox(height: 16),
        const Text(
          'No se pudo conectar con el backend',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verifica que CarniApp.Api este corriendo (dotnet run) '
          'y que el contenedor de SQL Server este activo.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _reintentar,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }

  Widget _buildStatus(HealthStatus status) {
    final dbColor =
        status.baseDeDatosConectada ? AppColors.stockNormal : AppColors.stockAgotado;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 48, color: AppColors.vino),
        const SizedBox(height: 16),
        Text(
          status.nombreNegocio ?? 'CarniApp',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(status.estado),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: dbColor),
            const SizedBox(width: 8),
            Text(
              status.baseDeDatosConectada
                  ? 'Base de datos conectada'
                  : 'Base de datos NO conectada',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Hora del servidor (UTC): ${status.horaServidorUtc}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _reintentar,
          child: const Text('Volver a consultar'),
        ),
      ],
    );
  }
}
