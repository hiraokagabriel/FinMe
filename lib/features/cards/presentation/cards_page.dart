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
  final double usedInOpenCycle;
  final bool currentCyclePaid;
  _CardSummary({
    required this.usedInOpenCycle,
    required this.currentCyclePaid,
  });
}

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late final CardsRepository _cardsRepository;
  List<CardEntity>           _cards     = const [];
  Map<String, _CardSummary>  _summaries = const {};
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

  /// Datas do ciclo aberto (próximo fechamento a partir de hoje).
  (DateTime start, DateTime end) _openCycleDates(CardEntity card) {
    final now        = DateTime.now();
    final today      = DateTime(now.year, now.month, now.day);
    final closingDay = _effectiveClosingDay(card);

    // Próximo fechamento
    DateTime cycleEnd = DateTime(today.year, today.month, closingDay);
    if (cycleEnd.isBefore(today)) {
      cycleEnd = DateTime(today.year, today.month + 1, closingDay);
    }

    final cycleStart = DateTime(cycleEnd.year, cycleEnd.month - 1, closingDay)
        .add(const Duration(days: 1));

    return (cycleStart, cycleEnd);
  }

  Future<void> _loadData() async {
    final locator      = RepositoryLocator.instance;
    final cards        = await _cardsRepository.getAll();
    final transactions = await locator.transactions.getAll();
    final stmtService  = StatementService.instance;

    final Map<String, _CardSummary> summaries = {};

    for (final card in cards) {
      if (card.type != CardType.credit) {
        summaries[card.id] =
            _CardSummary(usedInOpenCycle: 0, currentCyclePaid: false);
        continue;
      }

      final (start, end) = _openCycleDates(card);

      final usedInCycle = transactions
          .where((tx) =>
              tx.cardId == card.id &&
              tx.type == TransactionType.expense &&
              !tx.isProvisioned &&
              !tx.date.isBefore(start) &&
              !tx.date.isAfter(end))
          .fold(0.0, (s, tx) => s + tx.amount.amount);

      final isPaid =
          await stmtService.isPaid(card.id, end.year, end.month);

      summaries[card.id] = _CardSummary(
        // Fatura paga: ciclo anterior foi quitado, ciclo aberto tem saldo real
        usedInOpenCycle: isPaid ? 0.0 : usedInCycle,
        currentCyclePaid: isPaid,
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
    final used    = summary?.usedInOpenCycle ?? 0;
    final paid    = summary?.currentCyclePaid ?? false;
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
              style: AppText.badge.copyWith(
                  fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              'R\$ ${used.toStringAsFixed(2)} / R\$ ${limit.toStringAsFixed(2)}',
              style: AppText.secondary,
            ),
            if (paid) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.limitLow.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  'Paga',
                  style: AppText.badge
                      .copyWith(color: AppColors.limitLow),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDonutChart(CardEntity card) {
    final limit = card.limit;
    if (limit == null || limit <= 0) return const SizedBox.shrink();

    final summary = _summaries[card.id];
    final used    = summary?.usedInOpenCycle ?? 0;
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
          Text('Paga',
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
                                final isPaid   =
                                    summary?.currentCyclePaid ?? false;

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
                                              if (isCredit && isPaid)
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
