import '../../../core/network/api_client.dart';
import 'caja_dtos.dart';

/// RF-CAJA-001..005.
class CajaApi {
  final ApiClient _client;

  CajaApi(this._client);

  Future<EstadoCajaDto> actual(String token) async =>
      EstadoCajaDto.fromJson(await _client.getJson('/api/caja/actual', token: token));

  Future<CorteCajaDto> abrir(String token, double fondoInicial) async =>
      CorteCajaDto.fromJson(await _client.postJson('/api/caja/abrir', {'fondoInicial': fondoInicial}, token: token));

  Future<CorteCajaDto> registrarGasto(String token, String concepto, double importe) async => CorteCajaDto.fromJson(
      await _client.postJson('/api/caja/gastos', {'concepto': concepto, 'importe': importe}, token: token));

  Future<CorteCajaDto> cerrar(String token, double efectivoContado, String? notas) async => CorteCajaDto.fromJson(
      await _client.postJson('/api/caja/cerrar', {'efectivoContado': efectivoContado, 'notas': notas}, token: token));

  Future<CorteCajaDto> reabrir(String token, String id) async =>
      CorteCajaDto.fromJson(await _client.postJson('/api/caja/$id/reabrir', <String, dynamic>{}, token: token));

  Future<CorteCajaDto> detalle(String token, String id) async =>
      CorteCajaDto.fromJson(await _client.getJson('/api/caja/$id', token: token));

  Future<List<CorteCajaResumenDto>> historial(String token) async {
    final json = await _client.getJsonList('/api/caja?limite=30', token: token);
    return json.map((e) => CorteCajaResumenDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> ticket(String token, String id) async {
    final json = await _client.getJson('/api/caja/$id/ticket', token: token);
    return json['texto'] as String;
  }
}
