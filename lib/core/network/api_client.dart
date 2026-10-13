import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Cliente HTTP minimo para el Sprint 0. Se ira ampliando con manejo
/// de JWT (header Authorization), refresh automatico y manejo de
/// errores por codigo de estado conforme avancen los sprints.
class ApiClient {
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception(
        'El servidor respondio ${response.statusCode} al consultar $path',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
