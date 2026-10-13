import '../../../core/network/api_client.dart';
import 'catalogo_dtos.dart';

/// RF-INV-001/002: catalogo de tipos de animal y cortes.
class CatalogoApi {
  final ApiClient _client;

  CatalogoApi(this._client);

  Future<List<TipoAnimalDto>> listarTiposAnimal(String token) async {
    final json = await _client.getJsonList('/api/tipos-animal', token: token);
    return json.map((e) => TipoAnimalDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> crearTipoAnimal(String token, String nombre) => _client.postJson(
        '/api/tipos-animal',
        {'nombre': nombre},
        token: token,
      );

  Future<void> actualizarTipoAnimal(String token, String id, String nombre) => _client.putJson(
        '/api/tipos-animal/$id',
        {'nombre': nombre},
        token: token,
      );

  Future<void> desactivarTipoAnimal(String token, String id) =>
      _client.deleteNoContent('/api/tipos-animal/$id', token: token);

  Future<List<CorteDto>> listarCortes(String token) async {
    final json = await _client.getJsonList('/api/cortes', token: token);
    return json.map((e) => CorteDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> crearCorte(
    String token, {
    required String tipoAnimalId,
    required String nombre,
    required String unidadVenta,
    required double precioBase,
    required double stockMinimo,
  }) =>
      _client.postJson(
        '/api/cortes',
        {
          'tipoAnimalId': tipoAnimalId,
          'nombre': nombre,
          'unidadVenta': unidadVenta,
          'precioBase': precioBase,
          'stockMinimo': stockMinimo,
        },
        token: token,
      );

  Future<void> actualizarCorte(
    String token,
    String id, {
    required String tipoAnimalId,
    required String nombre,
    required String unidadVenta,
    required double precioBase,
    required double stockMinimo,
  }) =>
      _client.putJson(
        '/api/cortes/$id',
        {
          'tipoAnimalId': tipoAnimalId,
          'nombre': nombre,
          'unidadVenta': unidadVenta,
          'precioBase': precioBase,
          'stockMinimo': stockMinimo,
        },
        token: token,
      );

  Future<void> desactivarCorte(String token, String id) =>
      _client.deleteNoContent('/api/cortes/$id', token: token);
}
