import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/trend.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpTrend(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('DeltaBadge positivo bom usa success', (tester) async {
    await pumpTrend(tester, const DeltaBadge(ratio: 0.1));
    expect(find.text('▲ 10,0%'), findsOneWidget);
    expect(textColor(tester, '▲ 10,0%'), AppColors.light.success);
  });

  testWidgets('DeltaBadge positivo ruim usa danger', (tester) async {
    await pumpTrend(
      tester,
      const DeltaBadge(ratio: 0.1, higherIsBetter: false),
    );
    expect(textColor(tester, '▲ 10,0%'), AppColors.light.danger);
  });

  testWidgets('DeltaBadge negativo mostra seta para baixo em danger', (
    tester,
  ) async {
    await pumpTrend(tester, const DeltaBadge(ratio: -0.2));
    expect(find.text('▼ 20,0%'), findsOneWidget);
    expect(textColor(tester, '▼ 20,0%'), AppColors.light.danger);
  });

  testWidgets('DeltaBadge zero e arredondado a 0,0% ficam neutros sem seta', (
    tester,
  ) async {
    for (final ratio in [0.0, 0.0004, -0.0004]) {
      await pumpTrend(tester, DeltaBadge(ratio: ratio));
      expect(find.text('0,0%'), findsOneWidget);
      expect(textColor(tester, '0,0%'), AppColors.light.textSecondary);
      expect(find.textContaining('▲'), findsNothing);
      expect(find.textContaining('▼'), findsNothing);
    }
  });

  testWidgets('DeltaBadge sem razão não renderiza texto', (tester) async {
    await pumpTrend(tester, const DeltaBadge(ratio: null));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('Sparkline com 2+ valores desenha LineChart', (tester) async {
    await pumpTrend(tester, const Sparkline(values: [1, 3, 2]));
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('Sparkline com 1 valor vira só o espaço pedido', (tester) async {
    await pumpTrend(
      tester,
      const Sparkline(values: [5], width: 40, height: 12),
    );
    expect(find.byType(LineChart), findsNothing);
    expect(tester.getSize(find.byType(Sparkline)), const Size(40, 12));
  });
}
