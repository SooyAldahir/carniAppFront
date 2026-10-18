import 'package:carniapp/features/ventafacil/data/venta_facil_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsearDecimal acepta coma, punto y rechaza texto', () {
    expect(parsearDecimal('12,5'), 12.5);
    expect(parsearDecimal(' 7.25 '), 7.25);
    expect(parsearDecimal(''), isNull);
    expect(parsearDecimal('abc'), isNull);
  });

  test('sumaPorcentajes ignora vacios e invalidos', () {
    expect(sumaPorcentajes(['30', '', 'x', '12,5']), 42.5);
    expect(sumaPorcentajes([]), 0);
  });

  test('RepartoDto lee el reparto del servidor', () {
    final r = RepartoDto.fromJson({
      'tipoAnimalNombre': 'Res',
      'pesoKg': 200,
      'precioCompra': 10000,
      'lineas': [
        {'corteNombre': 'Bistec', 'porcentaje': 30, 'kgEstimados': 60, 'precioBase': 200, 'ventaEstimada': 12000},
      ],
      'kgAsignados': 60,
      'kgMerma': 140,
      'costoPorKg': 50,
      'ventaEstimadaTotal': 12000,
      'utilidadEstimada': 2000,
    });
    expect(r.lineas.single.kgEstimados, 60);
    expect(r.kgMerma, 140);
    expect(r.utilidadEstimada, 2000);
  });

  test('RendimientosDto admite porcentaje null', () {
    final r = RendimientosDto.fromJson({
      'tipoAnimalId': 't1',
      'cortes': [
        {'corteId': 'c1', 'corteNombre': 'Bistec', 'precioBase': 200, 'porcentaje': null},
      ],
      'totalPorcentaje': 0,
    });
    expect(r.cortes.single.porcentaje, isNull);
  });

  test('kgDeTextos ignora vacios y ceros, y devuelve null si hay algo invalido', () {
    expect(kgDeTextos({'a': '12,5', 'b': '', 'c': '0'}), {'a': 12.5});
    expect(kgDeTextos({'a': 'x'}), isNull);
    expect(kgDeTextos({'a': '-3'}), isNull);
    expect(kgDeTextos({}), isEmpty);
  });

  test('RendimientosDto lee lo aprendido', () {
    final r = RendimientosDto.fromJson({
      'tipoAnimalId': 't1',
      'cortes': [
        {'corteId': 'c1', 'corteNombre': 'Bistec', 'precioBase': 200, 'porcentaje': null, 'porcentajeAprendido': 24.5},
      ],
      'totalPorcentaje': 0,
      'lotesMedidos': 3,
      'lotesParaAprender': 3,
      'usaAprendido': true,
    });
    expect(r.usaAprendido, isTrue);
    expect(r.cortes.single.porcentajeAprendido, 24.5);
  });

  test('RepartoDto lee origen y si es estimado', () {
    final r = RepartoDto.fromJson({
      'tipoAnimalNombre': 'Res',
      'pesoKg': 100,
      'precioCompra': 5000,
      'lineas': [],
      'kgAsignados': 0,
      'kgMerma': 100,
      'costoPorKg': 50,
      'ventaEstimadaTotal': 0,
      'utilidadEstimada': -5000,
      'esEstimado': false,
      'origen': 'Pesado',
      'lotesMedidos': 2,
      'lotesParaAprender': 3,
    });
    expect(r.esEstimado, isFalse);
    expect(r.origen, 'Pesado');
  });
}
