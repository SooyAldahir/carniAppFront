import '../../../core/network/api_client.dart';
import 'negocio_dto.dart';

class NegocioApi {
  final ApiClient _client;

  NegocioApi(this._client);

  Future<NegocioDto> obtener(String accessToken) async {
    final json = await _client.getJson('/api/negocio', token: accessToken);
    return NegocioDto.fromJson(json);
  }
}
