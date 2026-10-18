import '../../../core/network/api_client.dart';
import 'clientes_dtos.dart';

/// RF-CLI-001, RF-CRED-001..003: clientes, credito y abonos.
class ClientesApi {
  final ApiClient _client;

  ClientesApi(this._client);

  Future<List<ClienteDto>> listar(String token, {String? texto}) async {
    final query = (texto == null || texto.trim().isEmpty) ? '' : '?q=${Uri.encodeQueryComponent(texto.trim())}';
    final json = await _client.getJsonList('/api/clientes$query', token: token);
    return json.map((e) => ClienteDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _cuerpo({
    required String nombre,
    String? telefono,
    String? direccion,
    String? referencias,
    required double limiteCredito,
  }) =>
      {
        'nombre': nombre,
        'telefono': telefono,
        'direccion': direccion,
        'referencias': referencias,
        'limiteCredito': limiteCredito,
      };

  Future<ClienteDto> crear(
    String token, {
    required String nombre,
    String? telefono,
    String? direccion,
    String? referencias,
    required double limiteCredito,
  }) async {
    final json = await _client.postJson(
      '/api/clientes',
      _cuerpo(nombre: nombre, telefono: telefono, direccion: direccion, referencias: referencias, limiteCredito: limiteCredito),
      token: token,
    );
    return ClienteDto.fromJson(json);
  }

  Future<ClienteDto> actualizar(
    String token,
    String id, {
    required String nombre,
    String? telefono,
    String? direccion,
    String? referencias,
    required double limiteCredito,
  }) async {
    final json = await _client.putJson(
      '/api/clientes/$id',
      _cuerpo(nombre: nombre, telefono: telefono, direccion: direccion, referencias: referencias, limiteCredito: limiteCredito),
      token: token,
    );
    return ClienteDto.fromJson(json);
  }

  Future<void> desactivar(String token, String id) => _client.deleteNoContent('/api/clientes/$id', token: token);

  Future<List<AbonoDto>> abonos(String token, String id) async {
    final json = await _client.getJsonList('/api/clientes/$id/abonos', token: token);
    return json.map((e) => AbonoDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Devuelve el cliente con el saldo ya actualizado.
  Future<ClienteDto> abonar(String token, String id, double importe) async {
    final json = await _client.postJson('/api/clientes/$id/abonos', {'importe': importe}, token: token);
    return ClienteDto.fromJson(json);
  }
}
