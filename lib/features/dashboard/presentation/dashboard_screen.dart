import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../caja/presentation/caja_screen.dart';
import '../../catalogos/presentation/catalogos_screen.dart';
import '../../clientes/presentation/clientes_screen.dart';
import '../../inventario/presentation/inventario_screen.dart';
import '../../negocio/data/negocio_api.dart';
import '../../negocio/data/negocio_dto.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../pos/presentation/ventas_screen.dart';
import '../../ventafacil/presentation/venta_facil_screen.dart';

/// Dashboard: muestra la marca del negocio (RF-CONFIG-003), los datos
/// de sesion del usuario autenticado y accesos a Catálogo e
/// Inventario. Los demas modulos (POS, Clientes, etc.) llegan en
/// sprints posteriores.
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
              const SizedBox(height: 32),
              if (usuario.tienePermiso('pos.vender')) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PosScreen()),
                  ),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Punto de venta'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VentasScreen()),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Ventas del dia'),
                ),
                const SizedBox(height: 12),
              ],
              if (usuario.tienePermiso('clientes.administrar') || usuario.tienePermiso('creditos.administrar')) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClientesScreen()),
                  ),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Clientes y credito'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CatalogosScreen()),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Catálogo (cortes y tipos de animal)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InventarioScreen()),
                ),
                icon: const Icon(Icons.warehouse_outlined),
                label: const Text('Inventario'),
              ),
              if (usuario.tienePermiso('caja.cortar')) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CajaScreen()),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Caja y corte'),
                ),
              ],
              if (usuario.tienePermiso('ventafacil.registrar')) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VentaFacilScreen()),
                  ),
                  icon: const Icon(Icons.pets_outlined),
                  label: const Text('Venta Facil (registrar animal)'),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Los demas modulos (Clientes, Caja...) llegan en los '
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
