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
    return _decodeOrThrow(response);
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
    return _decodeOrThrow(response);
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
    return _decodeOrThrow(response);
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

    if (response.statusCode >= 400) {
      _decodeOrThrow(response);
    }
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final bodyTexto = response.body.isEmpty ? '{}' : response.body;
    final decodificado = jsonDecode(bodyTexto);
    final json = decodificado is Map<String, dynamic> ? decodificado : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final mensaje = json['mensaje'] as String? ??
        'El servidor respondio ${response.statusCode}.';
    throw ApiException(response.statusCode, mensaje);
  }
}
