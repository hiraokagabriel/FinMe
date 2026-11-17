import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../cards/domain/card_insights.dart';
import '../../cards/domain/payment_card.dart';

/// Modo Ultra: parcelas já comprometidas por mês de vencimento, uma coluna por cartão com valor.
class InstallmentCommitmentsSection extends StatelessWidget {
  const InstallmentCommitmentsSection({
    super.key,
    required this.items,
    required this.cards,
  });

  final List<InstallmentCommitment> items;
  final Map<String, PaymentCard> cards;

  @override
  Widget build(BuildContext context) {
    final hasAny = items.any((i) => i.totalCents != 0);
    return SectionCard(
      title: 'Parcelas já comprometidas',
      child: !hasAny
          ? const EmptyState(
              icon: Icons.credit_score,
              message: 'Nenhuma parcela futura',
            )
          : _CommitmentsTable(items: items, cards: cards),
    );
  }
}

class _CommitmentsTable extends StatelessWidget {
  const _CommitmentsTable({required this.items, required this.cards});

  final List<InstallmentCommitment> items;
  final Map<String, PaymentCard> cards;

  @override
  Widget build(BuildContext context) {
    final cardIds = {for (final i in items) ...i.byCard.keys}.toList()
      ..sort((a, b) => (cards[a]?.name ?? a).compareTo(cards[b]?.name ?? b));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Mês')),
          const DataColumn(label: Text('Total'), numeric: true),
          for (final id in cardIds)
            DataColumn(label: Text(cards[id]?.name ?? id), numeric: true),
        ],
        rows: [
          for (final item in items)
            DataRow(
              cells: [
                DataCell(Text(formatMonth(item.month))),
                DataCell(MoneyText(item.totalCents)),
                for (final id in cardIds)
                  DataCell(
                    item.byCard.containsKey(id)
                        ? MoneyText(item.byCard[id]!)
                        : const Text('—'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
