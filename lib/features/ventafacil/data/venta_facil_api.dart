import '../../../core/network/api_client.dart';
import 'venta_facil_dtos.dart';

/// RF-VF: Venta Facil.
class VentaFacilApi {
  final ApiClient _client;

  VentaFacilApi(this._client);

  Future<RendimientosDto> rendimientos(String token, String tipoAnimalId) async =>
      RendimientosDto.fromJson(await _client.getJson('/api/venta-facil/rendimientos/$tipoAnimalId', token: token));

  /// [porcentajes]: corteId -> porcentaje (null limpia el corte).
  Future<RendimientosDto> guardarRendimientos(String token, String tipoAnimalId, Map<String, double?> porcentajes) async {
    final json = await _client.putJson(
      '/api/venta-facil/rendimientos',
      {
        'tipoAnimalId': tipoAnimalId,
        'cortes': porcentajes.entries.map((e) => {'corteId': e.key, 'porcentaje': e.value}).toList(),
      },
      token: token,
    );
    return RendimientosDto.fromJson(json);
  }

  Map<String, dynamic> _lote(String tipoAnimalId, double pesoKg, double precioCompra) =>
      {'tipoAnimalId': tipoAnimalId, 'pesoKg': pesoKg, 'precioCompra': precioCompra};

  Future<RepartoDto> previsualizar(String token, String tipoAnimalId, double pesoKg, double precioCompra) async =>
      RepartoDto.fromJson(await _client.postJson('/api/venta-facil/previsualizar', _lote(tipoAnimalId, pesoKg, precioCompra), token: token));

  Future<RepartoDto> registrarLote(String token, String tipoAnimalId, double pesoKg, double precioCompra) async =>
      RepartoDto.fromJson(await _client.postJson('/api/venta-facil/lotes', _lote(tipoAnimalId, pesoKg, precioCompra), token: token));

  Future<List<LoteDto>> lotes(String token) async {
    final json = await _client.getJsonList('/api/venta-facil/lotes', token: token);
    return json.map((e) => LoteDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}
