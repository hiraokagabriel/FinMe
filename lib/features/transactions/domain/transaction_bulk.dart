import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../categories/domain/transaction_category.dart';
import 'transaction.dart';

/// `changed` na ordem de entrada; `skipped` = selecionadas que a ação não se aplica.
typedef BulkResult = ({List<Transaction> changed, int skipped});

/// Tipo de categoria aceita pelo lançamento; null = não categorizável (transferência, pagamento de fatura).
CategoryKind? _categoryKindOf(TransactionType type) => switch (type) {
  TransactionType.expense => CategoryKind.expense,
  TransactionType.income => CategoryKind.income,
  _ => null,
};

/// category null = limpar categoria. Já iguais não entram em `changed` nem em `skipped`.
BulkResult bulkRecategorize(
  Iterable<Transaction> selected,
  TransactionCategory? category,
) {
  final changed = <Transaction>[];
  var skipped = 0;
  for (final t in selected) {
    final kind = _categoryKindOf(t.type);
    if (kind == null || (category != null && category.kind != kind)) {
      skipped++;
      continue;
    }
    if (t.categoryId == category?.id) {
      continue;
    }
    changed.add(t.copyWith(categoryId: category?.id));
  }
  return (changed: changed, skipped: skipped);
}

/// Mesma regra de "Confirmar provisionado" (SPEC §6.3), com uma data para todos.
BulkResult bulkConfirmPlanned(Iterable<Transaction> selected, DateTime paidOn) {
  final day = dateOnly(paidOn);
  final changed = <Transaction>[];
  var skipped = 0;
  for (final t in selected) {
    if (t.isPlanned) {
      // Compra de cartão ou parcela mantém a data: mudar o dia moveria a fatura ou o grupo.
      final keepDate = t.cardId != null || t.isInstallment;
      changed.add(
        t.copyWith(
          status: TransactionStatus.paid,
          date: keepDate ? t.date : day,
        ),
      );
    } else {
      skipped++;
    }
  }
  return (changed: changed, skipped: skipped);
}

/// `installmentGroupId` não nulos das selecionadas.
Set<String> installmentGroupsOf(Iterable<Transaction> selected) {
  final groups = <String>{};
  for (final t in selected) {
    final group = t.installmentGroupId;
    if (group != null) {
      groups.add(group);
    }
  }
  return groups;
}

/// `wholeGroups` acrescenta todas as parcelas (de `all`) dos grupos da seleção.
Set<String> bulkDeleteIds(
  Iterable<Transaction> selected,
  Iterable<Transaction> all, {
  required bool wholeGroups,
}) {
  final sel = selected.toList();
  final ids = {for (final t in sel) t.id};
  if (wholeGroups) {
    final groups = installmentGroupsOf(sel);
    for (final t in all) {
      final group = t.installmentGroupId;
      if (group != null && groups.contains(group)) {
        ids.add(t.id);
      }
    }
  }
  return ids;
}

/// Id da categoria comum à seleção; null se vazia, mista ou sem categoria.
String? commonCategoryId(Iterable<Transaction> selected) {
  final ids = selected.map((t) => t.categoryId).toSet();
  return ids.length == 1 ? ids.first : null;
}

/// Despesa e receita têm categoria editável inline.
bool canEditCategoryInline(Transaction t) => _categoryKindOf(t.type) != null;

/// Só despesa e receita não parceladas editam valor inline (transferência e pagamento de fatura não).
bool canEditAmountInline(Transaction t) =>
    _categoryKindOf(t.type) != null && !t.isInstallment;

/// Valor digitado na célula; null se inválido ou não positivo (amountCents > 0).
int? parseInlineAmount(String input) {
  final cents = parseMoney(input);
  return cents == null || cents <= 0 ? null : cents;
}
