import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/cards_repository.dart';
import '../domain/card_entity.dart';
import '../domain/card_type.dart';
import '../domain/statement_service.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../features/transactions/domain/transaction_entity.dart';
import '../../../features/transactions/domain/transaction_type.dart';
import 'card_statements_page.dart';
import 'new_card_page.dart';

class _CardSummary {
  /// Valor total comprometendo o limite:
  /// soma de todos os ciclos fechados NÃO pagos + ciclo aberto atual.
  final double totalCommitted;

  /// Quantos ciclos fechados ainda estão sem pagamento.
  final int unpaidClosedCycles;

  _CardSummary({
    required this.totalCommitted,
    required this.unpaidClosedCycles,
  });
}

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late final CardsRepository _cardsRepository;
  List<CardEntity>          _cards     = const [];
  Map<String, _CardSummary> _summaries = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cardsRepository = RepositoryLocator.instance.cards;
    _loadData();
  }

  int _effectiveClosingDay(CardEntity card) {
    if (card.closingDay != null) return card.closingDay!;
    return (card.dueDay - 7).clamp(1, 28);
  }

  Future<void> _loadData() async {
    final locator      = RepositoryLocator.instance;
    final cards        = await _cardsRepository.getAll();
    final transactions = await locator.transactions.getAll();
    final stmtService  = StatementService.instance;
    final now          = DateTime.now();
    final today        = DateTime(now.year, now.month, now.day);

    final Map<String, _CardSummary> summaries = {};

    for (final card in cards) {
      if (card.type != CardType.credit) {
        summaries[card.id] =
            _CardSummary(totalCommitted: 0, unpaidClosedCycles: 0);
        continue;
      }

      final closingDay = _effectiveClosingDay(card);

      // ── Ciclo aberto: do último fechamento até o próximo ────────────
      DateTime openEnd = DateTime(today.year, today.month, closingDay);
      if (openEnd.isBefore(today)) {
        openEnd = DateTime(today.year, today.month + 1, closingDay);
      }
      final openStart =
          DateTime(openEnd.year, openEnd.month - 1, closingDay)
              .add(const Duration(days: 1));

      double totalCommitted = 0.0;
      int    unpaidClosed   = 0;

      // ── Gastos do ciclo aberto (ainda não fechou, sempre comprome-
      //    te o limite independentemente de pagamento) ─────────────────
      final openSpend = transactions
          .where((tx) =>
              tx.cardId == card.id &&
              tx.type == TransactionType.expense &&
              !tx.isProvisioned &&
              !tx.date.isBefore(openStart) &&
              !tx.date.isAfter(openEnd))
          .fold(0.0, (s, tx) => s + tx.amount.amount);

      totalCommitted += openSpend;

      // ── Ciclos fechados: varre até 12 meses para trás ──────────────
      // Um ciclo fechado compromete o limite até que seja marcado pago.
      for (int i = 1; i <= 12; i++) {
        final cycleEnd =
            DateTime(openEnd.year, openEnd.month - i, closingDay);
        final cycleStart =
            DateTime(cycleEnd.year, cycleEnd.month - 1, closingDay)
                .add(const Duration(days: 1));

        // Ciclo ainda no futuro — pula (só processa fechados)
        if (cycleEnd.isAfter(today)) continue;

        final isPaid = await stmtService.isPaid(
          card.id,
          cycleEnd.year,
          cycleEnd.month,
        );

        if (!isPaid) {
          final cycleSpend = transactions
              .where((tx) =>
                  tx.cardId == card.id &&
                  tx.type == TransactionType.expense &&
                  !tx.isProvisioned &&
                  !tx.date.isBefore(cycleStart) &&
                  !tx.date.isAfter(cycleEnd))
              .fold(0.0, (s, tx) => s + tx.amount.amount);

          if (cycleSpend > 0) {
            totalCommitted += cycleSpend;
            unpaidClosed++;
          }
        }
        // Se há 3 ciclos consecutivos pagos no passado, para de varrer
        // (evita processar anos de histórico desnecessariamente)
        else if (unpaidClosed == 0 && i > 3) {
          break;
        }
      }

      summaries[card.id] = _CardSummary(
        totalCommitted:   totalCommitted,
        unpaidClosedCycles: unpaidClosed,
      );
    }

    setState(() {
      _cards     = cards;
      _summaries = summaries;
      _isLoading = false;
    });
  }

  String _cardTypeLabel(CardType type) {
    switch (type) {
      case CardType.credit: return 'Crédito';
      case CardType.debit:  return 'Débito';
    }
  }

  Future<void> _openCardForm({CardEntity? initial}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (context) => NewCardPage(initialCard: initial)),
    );
    if (result == true) await _loadData();
  }

  Future<void> _openStatements(CardEntity card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardStatementsPage(card: card)),
    );
    await _loadData();
  }

  Future<bool?> _confirmDelete(CardEntity card) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cartão'),
        content: Text('Deseja excluir o cartão "${card.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Excluir',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Color _limitColor(double ratio) {
    if (ratio < 0.5) return AppColors.limitLow;
    if (ratio < 0.8) return AppColors.limitMid;
    return AppColors.limitHigh;
  }

  Widget _buildLimitBar(CardEntity card) {
    final limit = card.limit;
    if (limit == null || limit <= 0) return const SizedBox.shrink();

    final summary = _summaries[card.id];
    final used    = summary?.totalCommitted ?? 0;
    final unpaid  = summary?.unpaidClosedCycles ?? 0;
    final ratio   = (used / limit).clamp(0.0, 1.0);
    final color   = _limitColor(ratio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: AppColors.limitTrack,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${(ratio * 100).toStringAsFixed(1)}%',
              style: AppText.badge
                  .copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                'R\$ ${used.toStringAsFixed(2)} / R\$ ${limit.toStringAsFixed(2)}',
                style: AppText.secondary,
              ),
            ),
            if (unpaid > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.limitHigh.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  '$unpaid fatura${unpaid > 1 ? 's' : ''} em aberto',
                  style: AppText.badge
                      .copyWith(color: AppColors.limitHigh),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonutChart(CardEntity card) {
    final limit = card.limit;
    if (limit == null || limit <= 0) return const SizedBox.shrink();

    final summary = _summaries[card.id];
    final used    = summary?.totalCommitted ?? 0;
    final free    = (limit - used).clamp(0.0, limit);
    final ratio   = (used / limit).clamp(0.0, 1.0);
    final color   = _limitColor(ratio);

    return SizedBox(
      width: 100,
      height: 100,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: [
            PieChartSectionData(
              value: used > 0 ? used : 0.001,
              color: color,
              title: '',
              radius: 18,
            ),
            PieChartSectionData(
              value: free > 0 ? free : 0.001,
              color: AppColors.limitTrack,
              title: '',
              radius: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.limitLow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 11, color: AppColors.limitLow),
          const SizedBox(width: 3),
          Text('Em dia',
              style: AppText.badge.copyWith(color: AppColors.limitLow)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeController = AppModeController.instance;

    return AnimatedBuilder(
      animation: modeController,
      builder: (context, _) {
        final mode     = modeController.mode;
        final isSimple = mode == AppMode.simple;
        final isUltra  = mode == AppMode.ultra;

        return Scaffold(
          appBar: AppBar(title: const Text('Cartões')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openCardForm(),
            icon: const Icon(Icons.add),
            label: const Text('Novo cartão'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (isSimple)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(AppSpacing.lg),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.sidebar,
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                        ),
                        child: Text(
                          'Detalhes de cartões são mais úteis no Modo Ultra.',
                          style: AppText.secondary,
                        ),
                      ),
                    Expanded(
                      child: _cards.isEmpty
                          ? AppEmptyState(
                              icon: Icons.credit_card_off_outlined,
                              title: 'Nenhum cartão cadastrado',
                              message:
                                  'Toque em "Novo cartão" para começar.',
                              actionLabel: 'Novo cartão',
                              onAction: () => _openCardForm(),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(
                                  bottom: 80, top: AppSpacing.sm),
                              itemCount: _cards.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final card     = _cards[index];
                                final isCredit =
                                    card.type == CardType.credit;
                                final summary  = _summaries[card.id];
                                final unpaid   =
                                    summary?.unpaidClosedCycles ?? 0;
                                final allPaid  = unpaid == 0;

                                return Dismissible(
                                  key: ValueKey(card.id),
                                  direction:
                                      DismissDirection.endToStart,
                                  confirmDismiss: (_) =>
                                      _confirmDelete(card),
                                  onDismissed: (_) async {
                                    await _cardsRepository
                                        .remove(card.id);
                                    await _loadData();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Cartão excluído com sucesso'),
                                    ));
                                  },
                                  background:
                                      const SizedBox.shrink(),
                                  secondaryBackground: Container(
                                    color: AppColors.danger,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg),
                                    child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white),
                                  ),
                                  child: InkWell(
                                    onTap: isCredit
                                        ? () => _openStatements(card)
                                        : () => _openCardForm(
                                            initial: card),
                                    child: Padding(
                                      padding: const EdgeInsets
                                          .symmetric(
                                              horizontal: AppSpacing.lg,
                                              vertical: AppSpacing.md),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      card.name,
                                                      style: AppText.body
                                                          .copyWith(
                                                        fontWeight:
                                                            FontWeight
                                                                .w600,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        height: 2),
                                                    Text(
                                                      isCredit
                                                          ? '${card.bankName} · ${_cardTypeLabel(card.type)} · Venc. dia ${card.dueDay} · Ver faturas'
                                                          : '${card.bankName} · ${_cardTypeLabel(card.type)} · Venc. dia ${card.dueDay}',
                                                      style: AppText
                                                          .secondary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isCredit && isUltra && allPaid)
                                                _buildPaidBadge(),
                                              const SizedBox(
                                                  width: AppSpacing.xs),
                                              if (isCredit)
                                                Icon(
                                                  Icons.chevron_right,
                                                  size: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            ],
                                          ),
                                          if (isUltra &&
                                              card.limit != null) ...[
                                            const SizedBox(
                                                height: AppSpacing.sm),
                                            Row(
                                              children: [
                                                _buildDonutChart(card),
                                                const SizedBox(
                                                    width:
                                                        AppSpacing.md),
                                                Expanded(
                                                  child:
                                                      _buildLimitBar(
                                                          card),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
