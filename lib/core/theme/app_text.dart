import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppFonts {
  static const sans = 'IBMPlexSans';
  static const serif = 'SourceSerif4';
}

abstract final class AppText {
  static const tabularFigures = [FontFeature.tabularFigures()];

  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: tabularFigures);

  static TextStyle screenTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!;

  static TextStyle kpi(BuildContext context) => TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: context.colors.textPrimary,
    fontFeatures: tabularFigures,
  );
}
