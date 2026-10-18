import 'package:flutter_test/flutter_test.dart';
import 'package:carniapp/features/pos/data/pos_dtos.dart';

void main() {
  test('redondear2 redondea a centavos como el backend', () {
    expect(redondear2(49.94667), 49.95);
    expect(redondear2(10), 10.0);
    expect(redondear2(0.333 * 149.99), 49.95);
  });

  test('cantidadTexto quita ceros sobrantes', () {
    expect(cantidadTexto(10), '10');
    expect(cantidadTexto(100), '100');
    expect(cantidadTexto(12.5), '12.5');
    expect(cantidadTexto(0.333), '0.333');
    expect(cantidadTexto(0), '0');
  });

  test('dinero siempre muestra dos decimales', () {
    expect(dinero(300), '\$300.00');
    expect(dinero(49.9), '\$49.90');
  });

  test('LineaCarrito calcula el importe con el precio del catalogo', () {
    final corte = CortePosDto(
      corteId: 'c1',
      nombre: 'Bistec',
      tipoAnimal: 'Res',
      unidadVenta: 'Peso',
      precioBase: 149.99,
      stockActual: 10,
    );
    expect(LineaCarrito(corte, 0.333).importe, 49.95);
    expect(LineaCarrito(corte, 2).importe, 299.98);
  });

  test('VentaDto.fromJson lee el ticket completo', () {
    final venta = VentaDto.fromJson({
      'id': 'v1',
      'folio': 1001,
      'fecha': '2026-10-18T19:00:00Z',
      'estado': 'Anulada',
      'motivoAnulacion': 'Error',
      'usuarioNombre': 'Admin',
      'subtotal': 300,
      'descuento': 0,
      'total': 300,
      'lineas': [
        {
          'corteId': 'c1',
          'corteNombre': 'Bistec',
          'unidadVenta': 'Peso',
          'cantidad': 2.5,
          'precioUnitario': 120,
          'importe': 300,
        }
      ],
      'pagos': [
        {'metodoPagoId': 'm1', 'metodoPago': 'Efectivo', 'importe': 300}
      ],
    });
    expect(venta.folio, 1001);
    expect(venta.anulada, isTrue);
    expect(venta.lineas.single.cantidad, 2.5);
    expect(venta.pagos.single.metodoPago, 'Efectivo');
  });
}
