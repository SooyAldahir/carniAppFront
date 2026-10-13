import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/health/presentation/health_check_screen.dart';

void main() {
  runApp(const CarniApp());
}

/// Punto de entrada de CarniApp. En Sprint 0 la app abre directo en la
/// pantalla de verificacion de conexion; a partir de Sprint 1 esto se
/// convierte en el flujo real: Login -> Dashboard -> POS/Inventario/...
class CarniApp extends StatelessWidget {
  const CarniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarniApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HealthCheckScreen(),
    );
  }
}
