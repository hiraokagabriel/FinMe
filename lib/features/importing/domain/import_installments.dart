import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/text_normalize.dart';
import '../../cards/domain/invoice_cycle.dart';
import '../../cards/domain/payment_card.dart';
import 'import_profile.dart';

/// Parcela detectada na descrição: `index` de `count` (1-based).
typedef InstallmentMark = ({int index, int count});

final RegExp _parcRe = RegExp(
  r'PARC(?:ELA)?\.?\s*(\d{1,2})\s*(?:/|DE)\s*(\d{1,2})',
);
final RegExp _deRe = RegExp(r'\b(\d{1,2})\s+DE\s+(\d{1,2})\b');
// Só no fim da descrição: evita datas "05/11/2026" no meio do texto.
final RegExp _endRe = RegExp(r'(?:^|\s)(\d{1,2})/(\d{1,2})$');

/// Detecta "PARC 03/10", "PARCELA 3 DE 10", "03 DE 10" ou "3/10" no fim.
/// O primeiro padrão que casar decide; inválido (index fora de 1..count) → null.
/// [date] (data do lançamento): só o padrão de fim igual ao dia/mês da compra ("UBER *TRIP 05/11"
/// em 05/11) é data, não parcela → null.
InstallmentMark? detectInstallment(String description, {DateTime? date}) {
  final s = foldText(description);
  final parc = _parcRe.firstMatch(s) ?? _deRe.firstMatch(s);
  final match = parc ?? _endRe.firstMatch(s);
  if (match == null) {
    return null;
  }
  final index = int.parse(match[1]!);
  final count = int.parse(match[2]!);
  if (index < 1 || index > count || count < 2 || count > 99) {
    return null;
  }
  if (parc == null &&
      date != null &&
      index == date.day &&
      count == date.month) {
    return null;
  }
  return (index: index, count: count);
}

/// Parcela só pelo padrão de fim ("3/10"): fraca, sem "PARC"/"DE". Começa desligada na prévia.
bool isWeakInstallment(String description) {
  final s = foldText(description);
  return _parcRe.firstMatch(s) == null &&
      _deRe.firstMatch(s) == null &&
      _endRe.hasMatch(s);
}

/// Datas das parcelas `index..count` de uma linha importada. A 1ª entrada é a própria
/// linha (posting) ou a parcela `index` no mês da compra (purchase). Em cartão de crédito,
/// cada parcela cai na fatura certa pelo ciclo (`invoice_cycle.dart`), mesmo com fechamento
/// em dia 29–31 e com histórico de ciclo.
List<({int index, DateTime date})> importedInstallmentDates({
  required DateTime lineDate,
  required int index,
  required int count,
  required InstallmentDateMode mode,
  PaymentCard? card,
}) {
  final isPosting = mode == InstallmentDateMode.posting;
  final base = isPosting ? lineDate : addMonthsClamped(lineDate, index - 1);

  if (card == null || card.kind != CardKind.credit) {
    return [
      for (var i = index; i <= count; i++)
        (index: i, date: addMonthsClamped(base, i - index)),
    ];
  }

  final alvoLinha = isPosting
      ? invoiceDueMonth(lineDate, card)
      : installmentDueMonth(lineDate, index, card);
  final fechamento = invoiceClosingDate(alvoLinha, card);
  final ancora = DateTime(
    fechamento.year,
    fechamento.month,
    fechamento.day - 1,
  );

  return [
    for (var i = index; i <= count; i++)
      (
        index: i,
        date: _creditInstallmentDate(
          base: base,
          offset: i - index,
          alvo: installmentDueMonth(ancora, i - index + 1, card),
          card: card,
        ),
      ),
  ];
}

DateTime _creditInstallmentDate({
  required DateTime base,
  required int offset,
  required YearMonth alvo,
  required PaymentCard card,
}) {
  final date = addMonthsClamped(base, offset);
  if (invoiceDueMonth(date, card) == alvo) {
    return date;
  }
  // Mês de compra cai na fatura errada (fechamento curto): usa o último dia do ciclo alvo.
  final fechamento = invoiceClosingDate(alvo, card);
  return DateTime(fechamento.year, fechamento.month, fechamento.day - 1);
}
