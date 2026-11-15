import 'package:flutter/widgets.dart';

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
