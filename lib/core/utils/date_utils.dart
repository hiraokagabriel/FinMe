import '../models/year_month.dart';

/// Meia-noite local do dia de [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Soma meses mantendo o dia, limitado ao fim do mês de destino (31/01 + 1 = 28/02).
DateTime addMonthsClamped(DateTime d, int months) =>
    YearMonth.fromDate(d).addMonths(months).dateAt(d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Chave ordenável "yyyyMMdd", ex.: "20261114".
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// Inverso de [dateKey]: "20261114" → meia-noite local. Lança [FormatException] se inválido.
DateTime parseDateKey(String key) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(key);
  if (match == null) {
    throw FormatException('dateKey inválido: $key');
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  // DateTime rola datas inválidas (30/02 → 02/03); a checagem rejeita esses casos.
  if (date.month != month || date.day != day) {
    throw FormatException('dateKey inválido: $key');
  }
  return date;
}
