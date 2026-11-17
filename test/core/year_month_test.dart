import 'package:finme/core/models/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YearMonth', () {
    test('key com mês de 2 dígitos', () {
      expect(const YearMonth(2026, 11).key, '2026-11');
      expect(const YearMonth(2026, 3).key, '2026-03');
    });

    test('fromKey e fromDate', () {
      expect(YearMonth.fromKey('2026-11'), const YearMonth(2026, 11));
      expect(
        YearMonth.fromDate(DateTime(2026, 11, 14)),
        const YearMonth(2026, 11),
      );
    });

    test('fromKey inválido lança FormatException', () {
      expect(() => YearMonth.fromKey('2026-13'), throwsFormatException);
      expect(() => YearMonth.fromKey('2026'), throwsFormatException);
      expect(() => YearMonth.fromKey('abc-01'), throwsFormatException);
    });

    test('virada de ano para frente e para trás', () {
      expect(const YearMonth(2026, 12).addMonths(1), const YearMonth(2027, 1));
      expect(const YearMonth(2026, 1).addMonths(-1), const YearMonth(2025, 12));
      expect(
        const YearMonth(2026, 1).addMonths(-13),
        const YearMonth(2024, 12),
      );
      expect(const YearMonth(2026, 11).addMonths(0), const YearMonth(2026, 11));
    });

    test('next e prev', () {
      expect(const YearMonth(2026, 12).next(), const YearMonth(2027, 1));
      expect(const YearMonth(2026, 1).prev(), const YearMonth(2025, 12));
    });

    test('daysInMonth em fevereiro bissexto e não bissexto', () {
      expect(const YearMonth(2024, 2).daysInMonth, 29);
      expect(const YearMonth(2026, 2).daysInMonth, 28);
      expect(const YearMonth(2026, 4).daysInMonth, 30);
      expect(const YearMonth(2026, 12).daysInMonth, 31);
    });

    test('firstDay e lastDay', () {
      expect(const YearMonth(2026, 2).firstDay, DateTime(2026, 2, 1));
      expect(const YearMonth(2026, 2).lastDay, DateTime(2026, 2, 28));
    });

    test('dateAt limita o dia ao fim do mês', () {
      expect(const YearMonth(2026, 2).dateAt(31), DateTime(2026, 2, 28));
      expect(const YearMonth(2024, 2).dateAt(31), DateTime(2024, 2, 29));
      expect(const YearMonth(2026, 2).dateAt(0), DateTime(2026, 2, 1));
      expect(const YearMonth(2026, 1).dateAt(15), DateTime(2026, 1, 15));
    });

    test('contains ignora o dia', () {
      expect(
        const YearMonth(2026, 11).contains(DateTime(2026, 11, 30)),
        isTrue,
      );
      expect(
        const YearMonth(2026, 11).contains(DateTime(2026, 12, 1)),
        isFalse,
      );
      expect(
        const YearMonth(2026, 11).contains(DateTime(2025, 11, 14)),
        isFalse,
      );
    });

    test('comparação cruza anos', () {
      const dec = YearMonth(2026, 12);
      const jan = YearMonth(2027, 1);
      expect(dec.compareTo(jan), lessThan(0));
      expect(dec < jan, isTrue);
      expect(dec <= dec, isTrue);
      expect(jan > dec, isTrue);
      expect(jan >= dec, isTrue);
      expect(dec > jan, isFalse);
    });

    test('igualdade e hashCode por (year, month)', () {
      const a = YearMonth(2026, 11);
      final b = YearMonth.fromKey('2026-11');
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect({a, b}.length, 1);
    });
  });
}
