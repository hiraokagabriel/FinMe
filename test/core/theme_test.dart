import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_palettes.dart';
import 'package:finme/core/theme/app_spacing.dart';
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

  test('categoryIcon resolve codepoint salvo e cai em label_outline', () {
    expect(categoryIcon(kCategoryIcons.first), Icons.restaurant);
    expect(categoryIcon(kCategoryIcons.last), Icons.category);
    expect(categoryIcon(0), Icons.label_outline);
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

  test('neutros quentes e superfícies novos (claro e escuro)', () {
    expect(AppColors.light.background, const Color(0xFFF6F5F2));
    expect(AppColors.light.sidebar, const Color(0xFFECEAE5));
    expect(AppColors.light.surface, const Color(0xFFFFFFFF));
    expect(AppColors.dark.background, const Color(0xFF161514));
    expect(AppColors.dark.surface, const Color(0xFF1F1E1C));
    expect(AppColors.dark.sidebar, const Color(0xFF2A2826));
  });

  test('primary permanece inalterado', () {
    expect(AppColors.light.primary, const Color(0xFF42A5F5));
    expect(AppColors.dark.primary, const Color(0xFF81D4FA));
  });

  test('AppMotion expõe durações de microanimação', () {
    expect(AppMotion.fast.inMilliseconds, 150);
    expect(AppMotion.normal.inMilliseconds, 200);
    expect(AppMotion.curve, Curves.easeOutCubic);
  });
}
