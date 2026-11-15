import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../recurring/domain/recurring_rule.dart';
import '../domain/payment_card.dart';
import 'card_form.dart';
import 'card_tile.dart';

/// Cartões e bancos. Sem banco informado, o cartão cai no grupo "Outros" (por último).
const _noBank = 'Outros';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final showArchived = ultra && _showArchived;
        final groups = _groupByBank(
          s.cards.all.where((c) => showArchived || !c.archived),
        );
        final subscriptions = _subscriptionCounts(s.recurring.all);
        final inset = MediaQuery.sizeOf(context).width < 600
            ? AppSpace.lg
            : AppSpace.xl;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Cartões',
              actions: [
                FilledButton.icon(
                  onPressed: () => showCardForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo cartão'),
                ),
              ],
            ),
            if (ultra)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _showArchived,
                      onChanged: (v) => setState(() => _showArchived = v),
                    ),
                    const Text('Mostrar arquivados'),
                  ],
                ),
              ),
            Expanded(
              child: groups.isEmpty
                  ? EmptyState(
                      icon: Icons.credit_card,
                      message: 'Nenhum cartão cadastrado.',
                      action: FilledButton.icon(
                        onPressed: () => showCardForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Novo cartão'),
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: ListView.builder(
                          padding: EdgeInsets.all(inset),
                          itemCount: groups.length,
                          itemBuilder: (context, i) {
                            final (bank, cards) = groups[i];
                            return _BankSection(
                              bank: bank,
                              cards: cards,
                              ultra: ultra,
                              subscriptions: subscriptions,
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Cabeçalho do banco (nome + contagem) e os cartões dele em Wrap.
class _BankSection extends StatelessWidget {
  const _BankSection({
    required this.bank,
    required this.cards,
    required this.ultra,
    required this.subscriptions,
  });

  final String bank;
  final List<PaymentCard> cards;
  final bool ultra;
  final Map<String, int> subscriptions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = cards.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                bank,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                '$count ${count == 1 ? 'cartão' : 'cartões'}',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.lg,
            runSpacing: AppSpace.lg,
            children: [
              for (final card in cards)
                CardTile(
                  card: card,
                  ultra: ultra,
                  subscriptions: subscriptions[card.id] ?? 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grupos (banco, cartões) em ordem alfabética, "Outros" por último; cartões por nome.
List<(String, List<PaymentCard>)> _groupByBank(Iterable<PaymentCard> cards) {
  final byBank = <String, List<PaymentCard>>{};
  for (final card in cards) {
    final bank = card.bankName.trim();
    byBank.putIfAbsent(bank.isEmpty ? _noBank : bank, () => []).add(card);
  }
  final names = byBank.keys.toList()..sort(_compareBanks);
  return [
    for (final name in names)
      (name, byBank[name]!..sort((a, b) => a.name.compareTo(b.name))),
  ];
}

int _compareBanks(String a, String b) {
  if (a == _noBank || b == _noBank) {
    return a == b ? 0 : (a == _noBank ? 1 : -1);
  }
  return a.compareTo(b);
}

/// Assinaturas ativas por cartão (badge do modo Ultra). Calculado uma vez por build.
Map<String, int> _subscriptionCounts(Iterable<RecurringRule> rules) {
  final counts = <String, int>{};
  for (final rule in rules) {
    final cardId = rule.cardId;
    if (cardId != null && rule.isSubscription && rule.active) {
      counts[cardId] = (counts[cardId] ?? 0) + 1;
    }
  }
  return counts;
}
