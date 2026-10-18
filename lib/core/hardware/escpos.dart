import 'dart:typed_data';

/// Genera los bytes ESC/POS para impresoras termicas de tickets (58/80 mm).
/// Es Dart puro (sin plugins) para poder probarlo sin hardware.
class EscPos {
  EscPos._();

  static const _acentos = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
    '¿': '?', '¡': '!', '€': 'E', '“': '"', '”': '"', '‘': "'", '’': "'",
    '–': '-', '—': '-', '·': '.', '×': 'x',
  };

  /// Convierte a ASCII imprimible: las impresoras baratas no comparten pagina de
  /// codigos, asi que se evita que "ñ" salga como basura.
  static String aAscii(String texto) {
    final b = StringBuffer();
    for (final r in texto.runes) {
      final c = String.fromCharCode(r);
      if (c == '\n' || c == '\t' || (r >= 32 && r < 127)) {
        b.write(c);
      } else {
        b.write(_acentos[c] ?? '?');
      }
    }
    return b.toString();
  }

  /// Ticket completo: inicializar, texto, avance de papel y corte parcial.
  /// [abrirCajon] manda el pulso de apertura de cajon (RJ11 de la impresora).
  static Uint8List ticket(String texto, {int avanceLineas = 4, bool cortar = true, bool abrirCajon = false}) {
    final bytes = <int>[
      0x1B, 0x40, // ESC @  : inicializa
      0x1B, 0x61, 0x00, // ESC a 0: alinear a la izquierda
    ];
    final limpio = aAscii(texto.replaceAll('\r\n', '\n')).trimRight();
    bytes.addAll(limpio.codeUnits);
    bytes.add(0x0A);
    bytes.addAll([0x1B, 0x64, avanceLineas.clamp(0, 255)]); // ESC d n: avanza n lineas
    if (cortar) bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // GS V 66 0: corte parcial
    if (abrirCajon) bytes.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]); // ESC p 0 25 250
    return Uint8List.fromList(bytes);
  }
}
