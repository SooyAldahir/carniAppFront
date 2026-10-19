import 'package:flutter/material.dart';
import '../../pos/data/pos_dtos.dart' show dinero;
import '../data/caja_dtos.dart';

/// Resumen de un turno: ventas por metodo, fondo, abonos, gastos y efectivo esperado/contado.
class ResumenCorteCard extends StatelessWidget {
  final CorteCajaDto corte;

  const ResumenCorteCard({super.key, required this.corte});

  Widget _fila(String texto, String valor, {bool negrita = false, Color? color}) {
    final estilo = TextStyle(fontWeight: negrita ? FontWeight.bold : null, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = corte;
    final dif = c.diferencia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.cerrado ? 'Turno cerrado' : 'Turno abierto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Abrio ${c.usuarioNombre ?? '-'} el ${fechaHora(c.fechaInicio)}'
              '${c.fechaCierre != null ? '\nCerro el ${fechaHora(c.fechaCierre!)}' : ''}',
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(),
            _fila('Ventas (${c.numeroVentas})', dinero(c.totalVentas), negrita: true),
            for (final m in c.porMetodo) _fila('   ${m.metodo}', dinero(m.importe)),
            if (c.ventasAnuladas > 0) _fila('Ventas anuladas', '${c.ventasAnuladas}'),
            const Divider(),
            _fila('Fondo inicial', dinero(c.fondoInicial)),
            _fila('+ Ventas en efectivo', dinero(c.ventasEfectivo)),
            _fila('+ Abonos de credito', dinero(c.abonosEfectivo)),
            _fila('- Gastos', dinero(c.totalGastos)),
            for (final g in c.gastos) _fila('      ${g.concepto}', dinero(g.importe)),
            const Divider(),
            _fila('Efectivo esperado', dinero(c.efectivoEsperado), negrita: true),
            if (c.efectivoContado != null) _fila('Efectivo contado', dinero(c.efectivoContado!), negrita: true),
            if (dif != null)
              _fila(
                etiquetaDiferencia(dif),
                dinero(dif.abs()),
                negrita: true,
                color: dif.abs() < 0.005
                    ? Colors.green.shade700
                    : (dif > 0 ? Colors.orange.shade800 : Colors.red.shade700),
              ),
            if (c.notas != null && c.notas!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Notas: ${c.notas}', style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}
