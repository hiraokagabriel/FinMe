import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/utils/date_utils.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/core/utils/id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('date_utils', () {
    test('dateOnly zera a hora', () {
      expect(dateOnly(DateTime(2026, 11, 14, 18, 30)), DateTime(2026, 11, 14));
    });

    test('addMonthsClamped limita ao fim do mês', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(
        addMonthsClamped(DateTime(2026, 12, 28), 1),
        DateTime(2027, 1, 28),
      );
      expect(
        addMonthsClamped(DateTime(2026, 3, 31), -1),
        DateTime(2026, 2, 28),
      );
    });

    test('isSameDay ignora a hora', () {
      expect(
        isSameDay(DateTime(2026, 11, 14, 1), DateTime(2026, 11, 14, 23)),
        isTrue,
      );
      expect(
        isSameDay(DateTime(2026, 11, 14), DateTime(2026, 11, 15)),
        isFalse,
      );
    });

    test('dateKey yyyyMMdd', () {
      expect(dateKey(DateTime(2026, 11, 14)), '20261114');
      expect(dateKey(DateTime(2026, 1, 5)), '20260105');
    });
  });

  group('formatMoney', () {
    test('formato pt-BR', () {
      expect(formatMoney(123456), 'R\$ 1.234,56');
      expect(formatMoney(0), 'R\$ 0,00');
      expect(formatMoney(5), 'R\$ 0,05');
      expect(formatMoney(100000000), 'R\$ 1.000.000,00');
    });

    test('negativo', () {
      expect(formatMoney(-5), '-R\$ 0,05');
      expect(formatMoney(-123456), '-R\$ 1.234,56');
    });

    test('signed prefixa + só em positivos', () {
      expect(formatMoney(1000, signed: true), '+R\$ 10,00');
      expect(formatMoney(-1000, signed: true), '-R\$ 10,00');
      expect(formatMoney(0, signed: true), 'R\$ 0,00');
    });

    test('hidden mascara o valor', () {
      expect(formatMoney(123456, hidden: true), 'R\$ ••••');
    });
  });

  group('parseMoney', () {
    test('aceita os formatos do SPEC', () {
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('1234,5'), 123450);
      expect(parseMoney('1234.56'), 123456);
      expect(parseMoney('R\$ 10'), 1000);
      expect(parseMoney('-5,00'), -500);
    });

    test('inválido retorna null', () {
      expect(parseMoney('abc'), isNull);
      expect(parseMoney(''), isNull);
      expect(parseMoney('-'), isNull);
      expect(parseMoney('1,2,3'), isNull);
      expect(parseMoney('12,345'), isNull);
    });

    test('parte inteira com mais de 13 dígitos é rejeitada', () {
      expect(parseMoney('9.999.999.999.999'), 999999999999900);
      expect(parseMoney('10.000.000.000.000'), isNull);
      expect(parseMoney('12345678901234'), isNull);
    });
  });

  group('formatDate e formatMonth', () {
    test('formatDate e formatShortDate', () {
      expect(formatDate(DateTime(2026, 11, 14)), '14/11/2026');
      expect(formatDate(DateTime(2026, 1, 5)), '05/01/2026');
      expect(formatShortDate(DateTime(2026, 11, 14)), '14/11');
    });

    test('formatMonth abreviado e formatMonthLong completo', () {
      expect(formatMonth(const YearMonth(2026, 11)), 'nov/2026');
      expect(formatMonth(const YearMonth(2026, 1)), 'jan/2026');
      expect(formatMonthLong(const YearMonth(2026, 11)), 'Novembro 2026');
      expect(formatMonthLong(const YearMonth(2026, 1)), 'Janeiro 2026');
      expect(formatMonthLong(const YearMonth(2026, 12)), 'Dezembro 2026');
    });
  });

  group('formatPercent', () {
    test('arredonda meio-para-cima com vírgula decimal', () {
      expect(formatPercent(0.1234), '12,3%');
      expect(formatPercent(-0.05), '-5,0%');
      expect(formatPercent(0), '0,0%');
      expect(formatPercent(1.0), '100,0%');
      expect(formatPercent(0.00049), '0,0%');
      expect(formatPercent(0.5, decimals: 0), '50%');
    });

    test('zero arredondado nunca sai com sinal', () {
      expect(formatPercent(-0.00049), '0,0%');
    });
  });

  group('newId', () {
    test('10.000 ids únicos', () {
      final ids = <String>{};
      for (var i = 0; i < 10000; i++) {
        ids.add(newId());
      }
      expect(ids.length, 10000);
    });
  });
}
