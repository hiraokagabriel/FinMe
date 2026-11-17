import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/card_insights.dart';

/// Melhor cartão para comprar hoje (SPEC §7.3). Simples: 1 linha com o 1º com limite livre.
/// Ultra: tabela com todos os cartões de crédito ativos, na ordem do domínio.
class BestCardPanel extends StatelessWidget {
  const BestCardPanel({super.key, required this.options, required this.ultra});

  final List<CardPurchaseOption> options;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return ultra ? _table(context) : _line(context);
  }

  Widget _line(BuildContext context) {
    final withLimit = options.where((o) => o.hasLimit);
    if (withLimit.isEmpty) {
      return const SizedBox.shrink();
    }
    final best = withLimit.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Text(
            'Melhor para comprar hoje: ${best.card.name} — fatura vence em '
            '${best.daysUntilDue} ${best.daysUntilDue == 1 ? 'dia' : 'dias'} '
            '(${formatShortDate(best.dueDate)})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: SectionCard(
        title: 'Melhor cartão para comprar hoje',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Cartão')),
              DataColumn(label: Text('Banco')),
              DataColumn(label: Text('Vencimento')),
              DataColumn(label: Text('Dias'), numeric: true),
              DataColumn(label: Text('Limite livre'), numeric: true),
            ],
            rows: [
              for (final o in options)
                DataRow(
                  cells: [
                    DataCell(Text(o.card.name)),
                    DataCell(Text(o.card.bankName)),
                    DataCell(Text(formatDate(o.dueDate))),
                    DataCell(Text('${o.daysUntilDue}')),
                    DataCell(
                      MoneyText(
                        o.freeLimitCents,
                        style: TextStyle(
                          color: o.freeLimitCents <= 0
                              ? c.danger
                              : c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
