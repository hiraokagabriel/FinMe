import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_text.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta [body] com AppScope real (store em memória) e tema claro.
Future<AppServices> pumpWith(WidgetTester tester, Widget body) async {
  final services = (await tester.runAsync(
    () => bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    ),
  ))!;
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: body),
        ),
      ),
    ),
  );
  return services;
}

Color? barColor(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .color;

void main() {
  testWidgets('MoneyText formata, assina e respeita hideValues', (
    tester,
  ) async {
    final services = await pumpWith(
      tester,
      const Column(children: [MoneyText(123456), MoneyText(500, signed: true)]),
    );
    expect(find.text('R\$ 1.234,56'), findsOneWidget);
    expect(find.text('+R\$ 5,00'), findsOneWidget);

    await tester.runAsync(
      () => services.settings.update((s) => s.copyWith(hideValues: true)),
    );
    await tester.pump();
    expect(find.text('R\$ ••••'), findsNWidgets(2));
    expect(find.text('R\$ 1.234,56'), findsNothing);
  });

  testWidgets('MoneyText colorBySign: positivo success, negativo danger', (
    tester,
  ) async {
    await pumpWith(
      tester,
      const Column(
        children: [
          MoneyText(100, colorBySign: true),
          MoneyText(-100, colorBySign: true),
        ],
      ),
    );
    Color? colorOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(colorOf('R\$ 1,00'), AppColors.light.success);
    expect(colorOf('-R\$ 1,00'), AppColors.light.danger);
  });

  testWidgets('MoneyField usa regra padrão e validator customizado', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await pumpWith(
      tester,
      Form(
        key: formKey,
        child: MoneyField(controller: controller),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Informe um valor válido'), findsOneWidget);

    controller.text = '0';
    expect(formKey.currentState!.validate(), isFalse);
    controller.text = '10,50';
    expect(formKey.currentState!.validate(), isTrue);

    final custom = GlobalKey<FormState>();
    await pumpWith(
      tester,
      Form(
        key: custom,
        child: MoneyField(
          controller: controller,
          validator: (c) => c == null || c > 100000 ? 'Muito alto' : null,
        ),
      ),
    );
    controller.text = '2000';
    expect(custom.currentState!.validate(), isFalse);
    controller.text = '20';
    expect(custom.currentState!.validate(), isTrue);
  });

  testWidgets('KpiTile mostra rótulo, valor e legenda', (tester) async {
    await pumpWith(
      tester,
      const KpiTile(label: 'Saldo', cents: 123456, caption: 'hoje'),
    );
    expect(find.text('Saldo'), findsOneWidget);
    expect(find.text('R\$ 1.234,56'), findsOneWidget);
    expect(find.text('hoje'), findsOneWidget);
  });

  testWidgets('LimitBar muda de cor por faixa e trata limite zero', (
    tester,
  ) async {
    Future<void> pumpBar(int used, int limit) =>
        pumpWith(tester, LimitBar(usedCents: used, limitCents: limit));

    await pumpBar(50, 100);
    expect(barColor(tester), AppColors.light.primary);

    await pumpBar(80, 100);
    expect(barColor(tester), AppColors.light.warning);

    await pumpBar(95, 100);
    expect(barColor(tester), AppColors.light.danger);

    await pumpBar(150, 100);
    expect(barColor(tester), AppColors.light.danger);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1.0,
    );

    await pumpBar(100, 0);
    expect(barColor(tester), AppColors.light.primary);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.0,
    );
  });

  testWidgets(
    'StatusBadge, PlannedMarker, SectionCard, PageHeader e EmptyState',
    (tester) async {
      await pumpWith(
        tester,
        Column(
          children: [
            const PageHeader(title: 'Painel', actions: [Text('ação')]),
            const SectionCard(
              title: 'Faturas',
              trailing: Text('extra'),
              child: Text('corpo'),
            ),
            StatusBadge(label: 'Vencida', color: AppColors.light.danger),
            const PlannedMarker(),
            EmptyState(
              icon: Icons.inbox,
              message: 'Nada aqui',
              action: TextButton(onPressed: () {}, child: const Text('Criar')),
            ),
          ],
        ),
      );
      expect(find.text('Painel'), findsOneWidget);
      expect(find.text('ação'), findsOneWidget);
      expect(find.text('Faturas'), findsOneWidget);
      expect(find.text('extra'), findsOneWidget);
      expect(find.text('corpo'), findsOneWidget);
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.byTooltip('Provisionado'), findsOneWidget);
      expect(find.text('Nada aqui'), findsOneWidget);
      expect(find.text('Criar'), findsOneWidget);
    },
  );

  testWidgets('MonthSelector avança e recua o mês', (tester) async {
    YearMonth? picked;
    await pumpWith(
      tester,
      MonthSelector(
        value: const YearMonth(2026, 11),
        onChanged: (m) => picked = m,
      ),
    );
    expect(find.text('Novembro 2026'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(picked, const YearMonth(2026, 12));

    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(picked, const YearMonth(2026, 10));
  });

  testWidgets('DateField mostra a data formatada', (tester) async {
    await pumpWith(
      tester,
      DateField(value: DateTime(2026, 11, 14), onChanged: (_) {}),
    );
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('14/11/2026'), findsOneWidget);
  });

  testWidgets('confirmDialog retorna true ao confirmar e false ao cancelar', (
    tester,
  ) async {
    bool? result;
    await pumpWith(
      tester,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await confirmDialog(
              ctx,
              title: 'Excluir',
              message: 'Confirma?',
              destructive: true,
            );
          },
          child: const Text('abrir'),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('MoneyText usa algarismos tabulares', (tester) async {
    await pumpWith(tester, const MoneyText(100));
    expect(
      tester.widget<Text>(find.text('R\$ 1,00')).style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('KpiTile usa serif, mostra trend e troca o valor', (
    tester,
  ) async {
    final cents = ValueNotifier<int>(100);
    addTearDown(cents.dispose);
    await pumpWith(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: cents,
        builder: (context, value, child) =>
            KpiTile(label: 'Saldo', cents: value, trend: const Text('X')),
      ),
    );
    expect(find.text('X'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('R\$ 1,00')).style?.fontFamily,
      AppFonts.serif,
    );

    cents.value = 2000;
    await tester.pumpAndSettle();
    expect(find.text('R\$ 20,00'), findsOneWidget);
    expect(find.text('R\$ 1,00'), findsNothing);
  });

  testWidgets('LimitBar tem tooltip com percentual e respeita hideValues', (
    tester,
  ) async {
    final services = await pumpWith(
      tester,
      const LimitBar(usedCents: 5000, limitCents: 10000),
    );
    expect(
      find.byTooltip('Usado R\$ 50,00 de R\$ 100,00 (50%)'),
      findsOneWidget,
    );

    await tester.runAsync(
      () => services.settings.update((s) => s.copyWith(hideValues: true)),
    );
    await tester.pump();
    expect(find.byTooltip('Usado R\$ •••• de R\$ •••• (50%)'), findsOneWidget);

    await pumpWith(tester, const LimitBar(usedCents: 5000, limitCents: 0));
    expect(find.byTooltip('Usado R\$ 50,00 de R\$ 0,00 (0%)'), findsOneWidget);
  });
}
