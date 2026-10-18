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
}
