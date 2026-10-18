import 'package:carniapp/core/hardware/escpos.dart';
import 'package:carniapp/features/pos/data/pos_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

CortePosDto _corte(String nombre, String? codigo) => CortePosDto(
      corteId: nombre,
      nombre: nombre,
      tipoAnimal: 'Res',
      unidadVenta: 'Peso',
      precioBase: 100,
      stockActual: 5,
      codigoBarras: codigo,
    );

void main() {
  group('EscPos', () {
    test('aAscii quita acentos y reemplaza caracteres no soportados', () {
      expect(EscPos.aAscii('Ñandú café ¿ok?'), 'Nandu cafe ?ok?');
      expect(EscPos.aAscii('precio 5€ 😀'), 'precio 5E ?');
    });

    test('ticket inicia, imprime, avanza y corta', () {
      final b = EscPos.ticket('Hola\nMundo', avanceLineas: 3);
      expect(b.sublist(0, 2), [0x1B, 0x40]);
      expect(String.fromCharCodes(b.sublist(5, 15)), 'Hola\nMundo');
      expect(b.sublist(b.length - 4), [0x1D, 0x56, 0x42, 0x00]);
      expect(b.contains(0x1B), isTrue);
    });

    test('abrirCajon agrega el pulso ESC p', () {
      final b = EscPos.ticket('x', cortar: false, abrirCajon: true);
      expect(b.sublist(b.length - 5), [0x1B, 0x70, 0x00, 0x19, 0xFA]);
    });
  });

  group('buscarPorCodigo', () {
    final catalogo = [_corte('Bistec', '7501'), _corte('Costilla', null), _corte('Molida', '7502')];

    test('encuentra por codigo exacto ignorando espacios del lector', () {
      expect(buscarPorCodigo(catalogo, ' 7502\n')?.nombre, 'Molida');
    });

    test('no encuentra codigos desconocidos ni vacios', () {
      expect(buscarPorCodigo(catalogo, '9999'), isNull);
      expect(buscarPorCodigo(catalogo, '  '), isNull);
    });
  });
}
