import '../../../core/network/api_client.dart';
import 'inventario_dtos.dart';

/// RF-INV-003/004/005/008.
class InventarioApi {
  final ApiClient _client;

  InventarioApi(this._client);

  Future<List<InventarioItemDto>> listar(String token) async {
    final json = await _client.getJsonList('/api/inventario', token: token);
    return json.map((e) => InventarioItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MovimientoDto>> kardex(String token, String corteId) async {
    final json = await _client.getJsonList('/api/inventario/$corteId/movimientos', token: token);
    return json.map((e) => MovimientoDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> ajustar(
    String token, {
    required String corteId,
    required String tipoMovimiento,
    required double cantidad,
    required String motivo,
  }) =>
      _client.postJson(
        '/api/inventario/ajustar',
        {
          'corteId': corteId,
          'tipoMovimiento': tipoMovimiento,
          'cantidad': cantidad,
          'motivo': motivo,
        },
        token: token,
      );
}
