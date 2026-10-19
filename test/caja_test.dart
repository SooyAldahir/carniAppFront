import 'package:carniapp/features/caja/data/caja_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _corte({bool cerrado = false}) => {
      'id': 'c1',
      'estado': cerrado ? 'Cerrado' : 'Abierto',
      'usuarioNombre': 'Ana',
      'fechaInicio': '2026-10-19T14:00:00Z',
      'fechaCierre': cerrado ? '2026-10-19T22:00:00Z' : null,
      'fondoInicial': 500,
      'numeroVentas': 3,
      'ventasAnuladas': 1,
      'totalVentas': 350,
      'porMetodo': [
        {'metodo': 'Efectivo', 'importe': 100},
        {'metodo': 'Tarjeta', 'importe': 50},
      ],
      'ventasEfectivo': 100,
      'abonosEfectivo': 20,
      'totalGastos': 40,
      'gastos': [
        {'id': 'g1', 'concepto': 'Hielo', 'importe': 40, 'usuarioNombre': 'Ana', 'fecha': '2026-10-19T15:00:00Z'},
      ],
      'efectivoEsperado': 580,
      'efectivoContado': cerrado ? 570 : null,
      'diferencia': cerrado ? -10 : null,
      'notas': null,
    };

void main() {
  test('CorteCajaDto lee un turno abierto', () {
    final c = CorteCajaDto.fromJson(_corte());
    expect(c.cerrado, isFalse);
    expect(c.efectivoContado, isNull);
    expect(c.porMetodo.length, 2);
    expect(c.gastos.single.concepto, 'Hielo');
    expect(c.efectivoEsperado, 580);
  });

  test('CorteCajaDto lee un turno cerrado con diferencia', () {
    final c = CorteCajaDto.fromJson(_corte(cerrado: true));
    expect(c.cerrado, isTrue);
    expect(c.diferencia, -10);
    expect(c.fechaCierre, isNotNull);
  });

  test('EstadoCajaDto sin turno', () {
    final e = EstadoCajaDto.fromJson({'abierta': false, 'corte': null});
    expect(e.abierta, isFalse);
    expect(e.corte, isNull);
  });

  test('etiquetaDiferencia', () {
    expect(etiquetaDiferencia(10), 'Sobrante');
    expect(etiquetaDiferencia(-0.5), 'Faltante');
    expect(etiquetaDiferencia(0), 'Cuadra');
    expect(etiquetaDiferencia(0.001), 'Cuadra');
  });

  test('CorteCajaResumenDto de un turno abierto trae nulos', () {
    final r = CorteCajaResumenDto.fromJson({
      'id': 'c1',
      'estado': 'Abierto',
      'usuarioNombre': null,
      'fechaInicio': '2026-10-19T14:00:00Z',
      'fechaCierre': null,
      'totalVentas': null,
      'efectivoEsperado': null,
      'efectivoContado': null,
      'diferencia': null,
    });
    expect(r.cerrado, isFalse);
    expect(r.totalVentas, isNull);
  });
}
