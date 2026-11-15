import '../models/year_month.dart';

const _monthsShort = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

const _monthsLong = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Valor em centavos: aceita "1.234,56", "1234,5", "1234.56", "R$ 10", "-5,00".
final _moneyPattern = RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+)(?:[,.](\d{1,2}))?$');

/// `hidden` vira "R$ ••••"; `signed` prefixa "+" em positivos.
String formatMoney(int cents, {bool hidden = false, bool signed = false}) {
  if (hidden) {
    return 'R\$ ••••';
  }
  final abs = cents.abs();
  final reais = _groupThousands(abs ~/ 100);
  final centavos = (abs % 100).toString().padLeft(2, '0');
  final sign = cents < 0 ? '-' : (signed && cents > 0 ? '+' : '');
  return '${sign}R\$ $reais,$centavos';
}

/// Retorna `null` se a entrada não for um valor monetário válido.
int? parseMoney(String input) {
  final s = input.replaceAll('R\$', '').replaceAll(RegExp(r'\s'), '');
  final negative = s.startsWith('-');
  final body = negative || s.startsWith('+') ? s.substring(1) : s;
  final m = _moneyPattern.firstMatch(body);
  if (m == null) {
    return null;
  }
  final digits = m.group(1)!.replaceAll('.', '');
  // Mais de 13 dígitos inteiros estouraria a faixa segura de centavos.
  if (digits.length > 13) {
    return null;
  }
  final reais = int.tryParse(digits);
  if (reais == null) {
    return null;
  }
  final frac = int.parse((m.group(2) ?? '0').padRight(2, '0'));
  final cents = reais * 100 + frac;
  return negative ? -cents : cents;
}

/// "14/11/2026"
String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// "14/11"
String formatShortDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// "nov/2026"
String formatMonth(YearMonth m) => '${_monthsShort[m.month - 1]}/${m.year}';

/// "Novembro 2026"
String formatMonthLong(YearMonth m) => '${_monthsLong[m.month - 1]} ${m.year}';

String _two(int n) => n.toString().padLeft(2, '0');

String _groupThousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buf.write('.');
    }
    buf.write(s[i]);
  }
  return buf.toString();
}
