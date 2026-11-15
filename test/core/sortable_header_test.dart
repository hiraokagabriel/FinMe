import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/sortable_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpHeader(
  WidgetTester tester, {
  required bool active,
  bool ascending = true,
  VoidCallback? onTap,
  bool alignEnd = false,
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: SortableHeaderLabel(
            label: 'Valor',
            active: active,
            ascending: ascending,
            onTap: onTap,
            alignEnd: alignEnd,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tap chama onTap uma vez', (tester) async {
    var taps = 0;
    await pumpHeader(tester, active: false, onTap: () => taps++);
    await tester.tap(find.text('Valor'));
    expect(taps, 1);
  });

  testWidgets('onTap null não tem Icon nem InkWell', (tester) async {
    await pumpHeader(tester, active: true);
    for (final type in [InkWell, Icon]) {
      expect(
        find.descendant(
          of: find.byType(SortableHeaderLabel),
          matching: find.byType(type),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('inativo esconde a seta; ativo descendente gira 0.5', (
    tester,
  ) async {
    await pumpHeader(tester, active: false, onTap: () {});
    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(SortableHeaderLabel),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 0);

    await pumpHeader(tester, active: true, ascending: false, onTap: () {});
    final rotation = tester.widget<AnimatedRotation>(
      find.descendant(
        of: find.byType(SortableHeaderLabel),
        matching: find.byType(AnimatedRotation),
      ),
    );
    expect(rotation.turns, 0.5);
  });

  testWidgets('cor do texto: ativo textPrimary, inativo textSecondary', (
    tester,
  ) async {
    await pumpHeader(tester, active: true, onTap: () {});
    expect(
      tester.widget<Text>(find.text('Valor')).style!.color,
      AppColors.light.textPrimary,
    );

    await pumpHeader(tester, active: false, onTap: () {});
    expect(
      tester.widget<Text>(find.text('Valor')).style!.color,
      AppColors.light.textSecondary,
    );
  });

  testWidgets('alignEnd alinha à direita e renderiza sem exceção', (
    tester,
  ) async {
    await pumpHeader(tester, active: true, alignEnd: true);
    final align = tester.widget<Align>(
      find.descendant(
        of: find.byType(SortableHeaderLabel),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, Alignment.centerRight);
    expect(tester.takeException(), isNull);
  });
}
