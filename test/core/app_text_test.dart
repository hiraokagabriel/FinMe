import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_text.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('titleLarge é serif e corpo é sans nos dois temas', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.textTheme.titleLarge!.fontFamily, AppFonts.serif);
      expect(theme.textTheme.bodyMedium!.fontFamily, AppFonts.sans);
    }
  });

  test('AppText.tabular adiciona figuras tabulares', () {
    expect(
      AppText.tabular(const TextStyle()).fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('tooltip usa espera de 300 ms', () {
    expect(
      AppTheme.light().tooltipTheme.waitDuration,
      const Duration(milliseconds: 300),
    );
  });

  testWidgets('AppText.kpi usa serif, 22 px e textPrimary do tema escuro', (
    tester,
  ) async {
    late TextStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            style = AppText.kpi(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(style.fontFamily, AppFonts.serif);
    expect(style.fontSize, 22);
    expect(style.color, AppColors.dark.textPrimary);
  });
}
