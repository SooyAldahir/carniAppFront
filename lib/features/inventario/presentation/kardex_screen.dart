import 'package:flutter/material.dart';
import '../data/inventario_dtos.dart';

/// RF-INV-008: historial de movimientos de un corte.
class KardexScreen extends StatelessWidget {
  final String corteNombre;
  final List<MovimientoDto> movimientos;

  const KardexScreen({super.key, required this.corteNombre, required this.movimientos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Movimientos · $corteNombre')),
      body: movimientos.isEmpty
          ? const Center(child: Text('Sin movimientos registrados todavia.'))
          : ListView.builder(
              itemCount: movimientos.length,
              itemBuilder: (context, index) {
                final m = movimientos[index];
                final esEntrada = m.cantidad > 0;
                return ListTile(
                  leading: Icon(
                    esEntrada ? Icons.arrow_circle_up : Icons.arrow_circle_down,
                    color: esEntrada ? Colors.green : Colors.red,
                  ),
                  title: Text('${m.tipoMovimiento} · ${m.cantidad.toStringAsFixed(3)}'),
                  subtitle: Text(
                    [
                      if (m.motivo != null && m.motivo!.isNotEmpty) m.motivo!,
                      if (m.usuarioNombre != null) 'Por: ${m.usuarioNombre}',
                      _formatoFecha(m.fecha),
                    ].join(' · '),
                  ),
                );
              },
            ),
    );
  }

  String _formatoFecha(DateTime fecha) {
    final local = fecha.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
