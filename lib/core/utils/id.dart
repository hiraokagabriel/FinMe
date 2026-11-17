import 'dart:math';

final _rng = Random();
var _seq = 0;

/// Id único por processo: timestamp (micros, base36) + contador (4 chars) + aleatório (6 chars).
String newId() {
  _seq = (_seq + 1) % 1679616; // 36^4: contador cabe em 4 chars base36
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final seq = _seq.toRadixString(36).padLeft(4, '0');
  final rnd = _rng.nextInt(0x7fffffff).toRadixString(36).padLeft(6, '0');
  return '$ts$seq$rnd';
}
