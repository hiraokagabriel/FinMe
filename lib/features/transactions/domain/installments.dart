import '../../../core/utils/date_utils.dart';
import 'transaction.dart';

/// Divide [base] em [count] parcelas mensais. O resto da divisão vai para a 1ª parcela.
/// Datas: `addMonthsClamped(base.date, i-1)`, então 31/01 → 28/02 → 31/03.
List<Transaction> buildInstallments({
  required Transaction base,
  required int count,
  required String groupId,
}) {
  assert(count >= 1, 'count deve ser >= 1');
  final each = base.amountCents ~/ count;
  final rest = base.amountCents - each * count;
  return [
    for (var i = 1; i <= count; i++)
      Transaction(
        id: '${groupId}_$i',
        type: base.type,
        amountCents: i == 1 ? each + rest : each,
        date: addMonthsClamped(base.date, i - 1),
        description: base.description,
        categoryId: base.categoryId,
        accountId: base.accountId,
        cardId: base.cardId,
        toAccountId: base.toAccountId,
        status: base.status,
        isBoleto: base.isBoleto,
        invoiceKey: base.invoiceKey,
        installmentGroupId: groupId,
        installmentIndex: i,
        installmentCount: count,
        recurringId: base.recurringId,
        notes: base.notes,
      ),
  ];
}
