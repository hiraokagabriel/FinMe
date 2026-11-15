import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_palettes.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/bank_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bankInitials segue as regras de palavras e caixa', () {
    expect(bankInitials('Banco Alfa'), 'BA');
    expect(bankInitials('beta'), 'BE');
    expect(bankInitials('  x '), 'X');
    expect(bankInitials(''), '?');
    expect(bankInitials('   '), '?');
    expect(bankInitials('Banco do Sul Norte'), 'BD');
  });

  test(
    'bankColorIndex é determinístico, ignora caixa/espaços e fica na paleta',
    () {
      expect(bankColorIndex('Alfa'), bankColorIndex('Alfa'));
      expect(bankColorIndex('Alfa'), bankColorIndex(' alfa '));
      for (final name in ['Alfa', 'Beta', 'Banco Inter', 'Nubank', '', 'x']) {
        final index = bankColorIndex(name);
        expect(index, inInclusiveRange(0, kEntityColors.length - 1));
      }
    },
  );

  testWidgets('BankAvatar mostra iniciais e respeita size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(child: BankAvatar(bankName: 'Banco Alfa', size: 32)),
        ),
      ),
    );
    expect(find.text('BA'), findsOneWidget);
    expect(tester.getSize(find.byType(BankAvatar)), const Size(32, 32));
  });

  testWidgets('BankAvatar sem nome mostra "?" em textSecondary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: BankAvatar(bankName: '')),
      ),
    );
    expect(find.text('?'), findsOneWidget);
    final text = tester.widget<Text>(find.text('?'));
    expect(text.style?.color, AppColors.light.textSecondary);
  });
}
