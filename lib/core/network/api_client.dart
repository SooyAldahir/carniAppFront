import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exception.dart';

/// Cliente HTTP generico. Cada llamada puede pasar un [token] opcional
/// (JWT de acceso) que se agrega como header Authorization: Bearer.
/// El manejo de refresco automatico de token vive en AuthProvider, no
/// aqui, para mantener este cliente simple y sin estado.
class ApiClient {
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    return _decodeMapaOThrow(response);
  }

  Future<List<dynamic>> getJsonList(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    return _decodeListaOThrow(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .post(uri, headers: _headers(token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    return _decodeMapaOThrow(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .put(uri, headers: _headers(token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    return _decodeMapaOThrow(response);
  }

  Future<void> postNoContent(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .post(uri, headers: _headers(token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    _lanzarSiError(response);
  }

  Future<void> deleteNoContent(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .delete(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    _lanzarSiError(response);
  }

  Map<String, dynamic> _decodeMapaOThrow(http.Response response) {
    _lanzarSiError(response);
    final bodyTexto = response.body.isEmpty ? '{}' : response.body;
    final decodificado = jsonDecode(bodyTexto);
    return decodificado is Map<String, dynamic> ? decodificado : <String, dynamic>{};
  }

  List<dynamic> _decodeListaOThrow(http.Response response) {
    _lanzarSiError(response);
    final bodyTexto = response.body.isEmpty ? '[]' : response.body;
    final decodificado = jsonDecode(bodyTexto);
    return decodificado is List<dynamic> ? decodificado : <dynamic>[];
  }

  void _lanzarSiError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String mensaje = 'El servidor respondio ${response.statusCode}.';

    if (response.body.isNotEmpty) {
      try {
        final decodificado = jsonDecode(response.body);
        if (decodificado is Map<String, dynamic> && decodificado['mensaje'] is String) {
          mensaje = decodificado['mensaje'] as String;
        }
      } catch (_) {
        // Body no era JSON valido; nos quedamos con el mensaje generico.
      }
    }

    throw ApiException(response.statusCode, mensaje);
  }
}
