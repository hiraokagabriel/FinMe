import 'package:finme/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCsvMoney', () {
    test('vírgula decimal, sem R\$ nem milhar', () {
      expect(formatCsvMoney(123456), '1234,56');
      expect(formatCsvMoney(-5000), '-50,00');
      expect(formatCsvMoney(0), '0,00');
      expect(formatCsvMoney(7), '0,07');
      expect(formatCsvMoney(123456789), '1234567,89');
    });
  });

  group('csvText', () {
    test('prefixa aspa simples em = + - @', () {
      expect(csvText('=SOMA(A1)'), "'=SOMA(A1)");
      expect(csvText('+1'), "'+1");
      expect(csvText('-x'), "'-x");
      expect(csvText('@a'), "'@a");
    });

    test('texto comum e vazio ficam inalterados', () {
      expect(csvText('Mercado'), 'Mercado');
      expect(csvText(''), '');
    });

    test('espaço antes de = + - @ também é protegido (trimLeft)', () {
      expect(csvText('  =SOMA(A1)'), "'  =SOMA(A1)");
      expect(csvText(' +1'), "' +1");
      expect(csvText('   @a'), "'   @a");
      // Espaço sozinho ou no meio não vira fórmula.
      expect(csvText(' Mercado'), ' Mercado');
      expect(csvText('a=b'), 'a=b');
    });

    test('tab e CR no início são protegidos, com ou sem fórmula depois', () {
      expect(csvText('\t=x'), "'\t=x");
      expect(csvText('\r=x'), "'\r=x");
      expect(csvText('\tabc'), "'\tabc");
      expect(csvText('\rabc'), "'\rabc");
      expect(csvText('a\t=x'), 'a\t=x');
    });
  });
}
