import 'package:flutter/material.dart';

/// Paleta de marca de CarniApp: vino/oxblood, hueso y bronce.
/// Misma paleta usada en el icono de la app y en el prototipo de Figma,
/// para que la marca sea coherente en todos los puntos de contacto.
class AppColors {
  AppColors._();

  static const Color vino = Color(0xFF6B1E23);
  static const Color hueso = Color(0xFFEFE6D8);
  static const Color bronce = Color(0xFFB08D57);
  static const Color carbon = Color(0xFF2A2420);

  // Colores funcionales para niveles de inventario (RF-INV-003)
  static const Color stockNormal = Color(0xFF2E7D32);
  static const Color stockBajo = Color(0xFFED6C02);
  static const Color stockAgotado = Color(0xFFC62828);
}
