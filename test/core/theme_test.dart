import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_palettes.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme.light() expõe AppColors claro', () {
    final theme = AppTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.extension<AppColors>(), isNotNull);
    expect(
      theme.extension<AppColors>()!.background,
      AppColors.light.background,
    );
  });

  test('AppTheme.dark() expõe AppColors escuro', () {
    final theme = AppTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<AppColors>(), isNotNull);
    expect(theme.extension<AppColors>()!.background, AppColors.dark.background);
  });

  test('AppColors.lerp interpola tokens e aceita tipo nulo', () {
    expect(
      AppColors.light.lerp(AppColors.dark, 0).background,
      AppColors.light.background,
    );
    expect(
      AppColors.light.lerp(AppColors.dark, 1).background,
      AppColors.dark.background,
    );
    expect(AppColors.light.lerp(null, 0.5), same(AppColors.light));
  });

  test('AppColors.copyWith altera só o token informado', () {
    final copy = AppColors.light.copyWith(primary: Colors.red);
    expect(copy.primary, Colors.red);
    expect(copy.surface, AppColors.light.surface);
  });

  test('border é textSecondary com alpha 0.15', () {
    expect(AppColors.light.border.a, closeTo(0.15, 0.01));
    expect(AppColors.light.border.r, AppColors.light.textSecondary.r);
  });

  test('paletas de entidade e ícones de categoria têm tamanho esperado', () {
    expect(kEntityColors, hasLength(10));
    expect(kCategoryIcons, hasLength(30));
  });

  testWidgets('context.colors resolve o token do tema ativo', (tester) async {
    late AppColors captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            captured = context.colors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(captured.primary, AppColors.dark.primary);
  });
}
