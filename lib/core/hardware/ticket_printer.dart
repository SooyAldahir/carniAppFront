import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'escpos.dart';

class ImpresoraConfig {
  final String host;
  final int puerto;

  const ImpresoraConfig(this.host, [this.puerto = 9100]);

  bool get valida => host.trim().isNotEmpty && puerto > 0 && puerto < 65536;
}

class ImpresoraException implements Exception {
  final String mensaje;
  ImpresoraException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Impresora termica de red (IP:9100, "RAW/JetDirect"), la conexion mas
/// universal para impresoras ESC/POS con Ethernet o WiFi. USB/Bluetooth
/// se agregaran segun el modelo que se compre (Sprint 6, pendiente).
class TicketPrinter {
  static const _kHost = 'impresora_host';
  static const _kPuerto = 'impresora_puerto';
  final FlutterSecureStorage _storage;

  TicketPrinter([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  Future<ImpresoraConfig?> cargarConfig() async {
    final host = await _storage.read(key: _kHost);
    if (host == null || host.isEmpty) return null;
    final puerto = int.tryParse(await _storage.read(key: _kPuerto) ?? '') ?? 9100;
    return ImpresoraConfig(host, puerto);
  }

  Future<void> guardarConfig(ImpresoraConfig config) async {
    await _storage.write(key: _kHost, value: config.host.trim());
    await _storage.write(key: _kPuerto, value: config.puerto.toString());
  }

  Future<void> imprimir(String texto, {ImpresoraConfig? config, bool abrirCajon = false}) async {
    if (kIsWeb) throw ImpresoraException('La impresion directa no esta disponible en la version web.');
    final cfg = config ?? await cargarConfig();
    if (cfg == null || !cfg.valida) {
      throw ImpresoraException('Configura primero la impresora (IP y puerto).');
    }
    Socket? socket;
    try {
      socket = await Socket.connect(cfg.host.trim(), cfg.puerto, timeout: const Duration(seconds: 4));
      socket.add(EscPos.ticket(texto, abrirCajon: abrirCajon));
      await socket.flush();
    } on SocketException catch (e) {
      throw ImpresoraException('No se pudo conectar a la impresora ${cfg.host}:${cfg.puerto} (${e.message}).');
    } on Exception {
      throw ImpresoraException('Tiempo de espera agotado al imprimir.');
    } finally {
      await socket?.close();
    }
  }
}
