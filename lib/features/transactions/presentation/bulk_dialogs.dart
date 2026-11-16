import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/transaction_category.dart';

/// category null = 'Sem categoria'.
typedef CategoryChoice = ({TransactionCategory? category});

/// Escopo da exclusão em massa: só as selecionadas ou os grupos de parcelas inteiros.
enum BulkDeleteScope { selected, wholeGroups }

/// Valor interno do item 'Sem categoria' (não colide com ids `cat_*`).
const _noCategoryKey = '__sem_categoria__';

/// Escolhe a categoria para a seleção. Cancelar ou fechar → null.
Future<CategoryChoice?> showBulkCategoryDialog(
  BuildContext context, {
  required int count,
  required List<TransactionCategory> categories,
}) {
  final expenses = categories
      .where((c) => c.kind == CategoryKind.expense)
      .toList(growable: false);
  final incomes = categories
      .where((c) => c.kind == CategoryKind.income)
      .toList(growable: false);
  final byId = {for (final c in categories) c.id: c};
  String? chosen;
  var answered = false;
  return showDialog<CategoryChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) {
        // Duplo clique faria um segundo pop, fechando a rota de baixo.
        void close([CategoryChoice? value]) {
          if (!answered) {
            answered = true;
            Navigator.of(ctx).pop(value);
          }
        }

        return AlertDialog(
          title: Text('Recategorizar $count'),
          content: SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              initialValue: null,
              isExpanded: true,
              hint: const Text('Escolha uma categoria'),
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                const DropdownMenuItem(
                  value: _noCategoryKey,
                  child: Text('Sem categoria'),
                ),
                for (final c in _byName(expenses))
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
                for (final c in _byName(incomes))
                  DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.name} (receita)'),
                  ),
              ],
              onChanged: (v) => setDialog(() => chosen = v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => close(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: chosen == null
                  ? null
                  : () => close((
                      category: chosen == _noCategoryKey ? null : byId[chosen],
                    )),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    ),
  );
}

List<TransactionCategory> _byName(List<TransactionCategory> list) =>
    [...list]..sort((a, b) => a.name.compareTo(b.name));

/// Data do pagamento para os provisionados selecionados. Cancelar ou fechar → null.
Future<DateTime?> showBulkConfirmDialog(
  BuildContext context, {
  required int count,
  required DateTime initialDate,
}) {
  var date = initialDate;
  var answered = false;
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) {
        // Duplo clique faria um segundo pop, fechando a rota de baixo.
        void close([DateTime? value]) {
          if (!answered) {
            answered = true;
            Navigator.of(ctx).pop(value);
          }
        }

        return AlertDialog(
          title: Text(
            count == 1
                ? 'Confirmar 1 provisionado'
                : 'Confirmar $count provisionados',
          ),
          content: SizedBox(
            width: 320,
            child: DateField(
              value: date,
              label: 'Data do pagamento',
              onChanged: (d) => setDialog(() => date = d),
            ),
          ),
          actions: [
            TextButton(onPressed: () => close(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => close(date),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    ),
  );
}

/// Sem parcelas na seleção: confirmação simples. Com parcelas: escolhe o escopo.
/// Cancelar ou fechar → null.
Future<BulkDeleteScope?> showBulkDeleteDialog(
  BuildContext context, {
  required int count,
  required int groups,
  required int wholeGroupsCount,
}) async {
  final title = count == 1
      ? 'Excluir 1 transação?'
      : 'Excluir $count transações?';
  if (groups == 0) {
    final ok = await confirmDialog(
      context,
      title: title,
      message: 'As transações selecionadas serão removidas.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    return ok ? BulkDeleteScope.selected : null;
  }
  var answered = false;
  return showDialog<BulkDeleteScope>(
    context: context,
    builder: (ctx) {
      // Duplo clique faria um segundo pop, fechando a rota de baixo.
      void close([BulkDeleteScope? value]) {
        if (!answered) {
          answered = true;
          Navigator.of(ctx).pop(value);
        }
      }

      return AlertDialog(
        title: Text(title),
        content: Text(
          groups == 1
              ? '1 grupo de parcelas na seleção.'
              : '$groups grupos de parcelas na seleção.',
        ),
        actions: [
          TextButton(onPressed: () => close(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => close(BulkDeleteScope.selected),
            child: Text('Só as $count selecionadas'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colors.danger,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => close(BulkDeleteScope.wholeGroups),
            child: Text('Grupos inteiros ($wholeGroupsCount lançamentos)'),
          ),
        ],
      );
    },
  );
}
