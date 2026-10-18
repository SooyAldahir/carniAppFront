import 'package:carniapp/features/clientes/data/clientes_dtos.dart';
import 'package:carniapp/features/pos/data/pos_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ClienteDto lee saldo y credito disponible del servidor', () {
    final c = ClienteDto.fromJson({
      'id': 'c1',
      'nombre': 'Don Pepe',
      'telefono': null,
      'direccion': 'Calle 1',
      'referencias': null,
      'limiteCredito': 500,
      'saldoCredito': 120.5,
      'creditoDisponible': 379.5,
    });

    expect(c.nombre, 'Don Pepe');
    expect(c.telefono, isNull);
    expect(c.tieneSaldo, isTrue);
    expect(c.creditoDisponible, 379.5);
  });

  test('ClienteDto sin deuda no tiene saldo', () {
    final c = ClienteDto(id: 'x', nombre: 'A', limiteCredito: 0, saldoCredito: 0, creditoDisponible: 0);
    expect(c.tieneSaldo, isFalse);
  });

  test('AbonoDto convierte la fecha a hora local', () {
    final a = AbonoDto.fromJson({'id': 'a', 'importe': 50, 'fecha': '2026-10-18T20:00:00Z', 'usuarioNombre': 'Ana'});
    expect(a.importe, 50.0);
    expect(a.fecha.isUtc, isFalse);
    expect(a.usuarioNombre, 'Ana');
  });

  test('MetodoPagoDto reconoce Credito sin importar mayusculas', () {
    expect(MetodoPagoDto(id: '1', nombre: 'Credito', disponible: true).esCredito, isTrue);
    expect(MetodoPagoDto(id: '2', nombre: 'credito', disponible: true).esCredito, isTrue);
    expect(MetodoPagoDto(id: '3', nombre: 'Efectivo', disponible: true).esCredito, isFalse);
  });

  test('VentaDto trae el nombre del cliente cuando lo hay', () {
    Map<String, dynamic> base(Object? cliente) => {
          'id': 'v',
          'folio': 1,
          'fecha': '2026-10-18T20:00:00Z',
          'estado': 'Completada',
          'motivoAnulacion': null,
          'usuarioNombre': 'Ana',
          'subtotal': 100,
          'descuento': 0,
          'total': 100,
          'lineas': [],
          'pagos': [],
          'clienteNombre': cliente,
          'clienteDireccion': cliente == null ? null : 'Calle 5',
          'nota': cliente == null ? null : 'Puerta de atras',
        };

    expect(VentaDto.fromJson(base('Dona Lupe')).clienteNombre, 'Dona Lupe');
    expect(VentaDto.fromJson(base('Dona Lupe')).clienteDireccion, 'Calle 5');
    expect(VentaDto.fromJson(base('Dona Lupe')).nota, 'Puerta de atras');
    expect(VentaDto.fromJson(base(null)).clienteNombre, isNull);
  });
}
