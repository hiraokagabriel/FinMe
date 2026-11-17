import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double card = 8;
  static const double chip = 4;

  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius chipBorder = BorderRadius.all(
    Radius.circular(chip),
  );
}

/// Durações e curva de microanimações. Toda animação do app usa estes valores.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;
}
