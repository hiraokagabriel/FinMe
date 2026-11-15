import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/recurring/presentation/recurring_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('duplo tap no Salvar da recorrência cria só 1 regra', (
    tester,
  ) async {
    final s = (await tester.runAsync(() async {
      final services = await bootstrap(
        storeFactory: (_) => MemoryRecordStore(),
        clock: () => DateTime(2026, 11, 14),
      );
      await seedDemo(services);
      return services;
    }))!;
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(
      AppScope(
        services: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRecurringForm(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Assinatura dupla',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '19,90',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banco Alfa · Conta corrente').last);
    await tester.pumpAndSettle();

    // Dois cliques no mesmo frame: o 2º chega antes do rebuild que desabilita o botão.
    final save = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    save();
    save();
    await tester.pumpAndSettle();

    expect(
      s.recurring.all.where((r) => r.description == 'Assinatura dupla'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}
