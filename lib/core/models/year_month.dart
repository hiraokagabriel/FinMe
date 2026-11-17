/// Mês de calendário (ano + mês 1..12), sem componente de dia.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'month deve estar em 1..12');

  factory YearMonth.fromDate(DateTime d) => YearMonth(d.year, d.month);

  /// Aceita "2026-11".
  factory YearMonth.fromKey(String key) {
    final parts = key.split('-');
    final year = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final month = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (year == null || month == null || month < 1 || month > 12) {
      throw FormatException('YearMonth inválido: $key');
    }
    return YearMonth(year, month);
  }

  final int year;
  final int month;

  /// Chave "yyyy-MM", ex.: "2026-11".
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  DateTime get firstDay => DateTime(year, month, 1);

  DateTime get lastDay => DateTime(year, month, daysInMonth);

  /// Aceita negativo e cruza anos.
  YearMonth addMonths(int n) {
    final index = _index + n;
    return YearMonth(index ~/ 12, index % 12 + 1);
  }

  YearMonth next() => addMonths(1);

  YearMonth prev() => addMonths(-1);

  /// Dia limitado a 1..daysInMonth. Retorna meia-noite local.
  DateTime dateAt(int day) {
    final clamped = day < 1 ? 1 : (day > daysInMonth ? daysInMonth : day);
    return DateTime(year, month, clamped);
  }

  bool contains(DateTime d) => d.year == year && d.month == month;

  int get _index => year * 12 + (month - 1);

  @override
  int compareTo(YearMonth other) => _index.compareTo(other._index);

  bool operator <(YearMonth other) => compareTo(other) < 0;

  bool operator <=(YearMonth other) => compareTo(other) <= 0;

  bool operator >(YearMonth other) => compareTo(other) > 0;

  bool operator >=(YearMonth other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}
