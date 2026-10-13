import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Resuelve la URL base del backend segun la plataforma donde corre
/// Flutter. El API (CarniApp.Api) corre en http://localhost:5080
/// durante desarrollo local (ver Properties/launchSettings.json).
///
/// Nota: en un dispositivo fisico (celular real, no emulador) hay que
/// cambiar esto por la IP de la red local de la Mac donde corre el API,
/// por ejemplo "http://192.168.1.50:5080". Eso se resuelve en un sprint
/// posterior con variables de entorno/configuracion por build.
class AppConfig {
  AppConfig._();

  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5080';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 es el alias del host dentro del emulador de Android.
      return 'http://10.0.2.2:5080';
    }
    // iOS simulator, macOS, Windows y Linux desktop ven "localhost" igual
    // que el navegador.
    return 'http://localhost:5080';
  }
}
