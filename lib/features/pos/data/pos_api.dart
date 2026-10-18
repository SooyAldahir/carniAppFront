import '../../../core/network/api_client.dart';
import 'pos_dtos.dart';

/// RF-POS-001/002/008/011 y RN-003.
class PosApi {
  final ApiClient _client;

  PosApi(this._client);

  Future<List<CortePosDto>> catalogo(String token) async {
    final json = await _client.getJsonList('/api/ventas/catalogo', token: token);
    return json.map((e) => CortePosDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MetodoPagoDto>> metodosPago(String token) async {
    final json = await _client.getJsonList('/api/ventas/metodos-pago', token: token);
    return json.map((e) => MetodoPagoDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VentaDto> crearVenta(
    String token, {
    required List<LineaCarrito> lineas,
    required List<PagoCaptura> pagos,
    double descuentoTotal = 0,
  }) async {
    final json = await _client.postJson(
      '/api/ventas',
      {
        'lineas': lineas
            .map((l) => {'corteId': l.corte.corteId, 'cantidad': l.cantidad, 'descuento': l.descuento})
            .toList(),
        'pagos': pagos.map((p) => {'metodoPagoId': p.metodoPagoId, 'importe': p.importe}).toList(),
        'descuentoTotal': descuentoTotal,
      },
      token: token,
    );
    return VentaDto.fromJson(json);
  }

  /// [desde]/[hasta] se mandan en UTC; el backend filtra Fecha en [desde, hasta).
  Future<List<VentaResumenDto>> listar(String token, {required DateTime desde, required DateTime hasta}) async {
    final query = 'desde=${Uri.encodeQueryComponent(desde.toUtc().toIso8601String())}'
        '&hasta=${Uri.encodeQueryComponent(hasta.toUtc().toIso8601String())}';
    final json = await _client.getJsonList('/api/ventas?$query', token: token);
    return json.map((e) => VentaResumenDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VentaDto> obtener(String token, String id) async {
    final json = await _client.getJson('/api/ventas/$id', token: token);
    return VentaDto.fromJson(json);
  }

  Future<VentaDto> anular(String token, String id, String motivo) async {
    final json = await _client.postJson('/api/ventas/$id/anular', {'motivo': motivo}, token: token);
    return VentaDto.fromJson(json);
  }

  /// Ticket en texto plano de 32 columnas (RF-POS-010).
  Future<String> ticket(String token, String id) async {
    final json = await _client.getJson('/api/ventas/$id/ticket', token: token);
    return json['texto'] as String;
  }
}
