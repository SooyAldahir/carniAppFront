import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

void main() {
  runApp(const CarniApp());
}

/// Punto de entrada de CarniApp. A partir de Sprint 1 el flujo real es:
/// intenta sesion automatica -> Login (o Bootstrap la primera vez) ->
/// Dashboard -> modulos (POS/Inventario/... en sprints siguientes).
class CarniApp extends StatelessWidget {
  const CarniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..intentarSesionAutomatica(),
      child: MaterialApp(
        title: 'CarniApp',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _RaizSesion(),
      ),
    );
  }
}

class _RaizSesion extends StatelessWidget {
  const _RaizSesion();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.desconocido:
      case AuthStatus.autenticando:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.autenticado:
        return const DashboardScreen();
      case AuthStatus.noAutenticado:
        return const LoginScreen();
    }
  }
}
