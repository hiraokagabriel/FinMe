import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/cards_repository.dart';
import '../domain/card_entity.dart';
import '../domain/card_type.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/repository_locator.dart';
import '../../../features/transactions/domain/transaction_entity.dart';
import '../../../features/transactions/domain/transaction_type.dart';
import 'new_card_page.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late final CardsRepository _cardsRepository;
  List<CardEntity> _cards = const [];
  Map<String, double> _usedByCard = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cardsRepository = RepositoryLocator.instance.cards;
    _loadData();
  }

  Future<void> _loadData() async {
    final locator = RepositoryLocator.instance;
    final cards = await _cardsRepository.getAll();
    final transactions = await locator.transactions.getAll();

    final Map<String, double> used = {};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense && tx.cardId != null) {
        used[tx.cardId!] = (used[tx.cardId!] ?? 0) + tx.amount.amount;
      }
    }

    setState(() {
      _cards = cards;
      _usedByCard = used;
      _isLoading = false;
    });
  }

  String _cardTypeLabel(CardType type) {
    switch (type) {
      case CardType.credit:
        return 'Credito';
      case CardType.debit:
        return 'Debito';
    }
  }

  Future<void> _openCardForm({CardEntity? initial}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NewCardPage(initialCard: initial),
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  Future<bool?> _confirmDelete(CardEntity card) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir cartao'),
          content: Text('Deseja excluir o cartao "${card.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLimitBar(CardEntity card) {
    final limit = card.limit;
    if (limit == null || limit <= 0) return const SizedBox.shrink();

    final used = _usedByCard[card.id] ?? 0;
    final ratio = (used / limit).clamp(0.0, 1.0);
    final percent = (ratio * 100).toStringAsFixed(1);

    Color barColor;
    if (ratio < 0.5) {
      barColor = Colors.green;
    } else if (ratio < 0.8) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  color: barColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'R\$ ${used.toStringAsFixed(2)} / R\$ ${limit.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDonutChart(CardEntity card) {
    final limit = card.limit;
    if (limit == null || limit <= 0) return const SizedBox.shrink();

    final used = _usedByCard[card.id] ?? 0;
    final free = (limit - used).clamp(0.0, limit);
    final ratio = (used / limit).clamp(0.0, 1.0);

    Color usedColor;
    if (ratio < 0.5) {
      usedColor = Colors.green;
    } else if (ratio < 0.8) {
      usedColor = Colors.orange;
    } else {
      usedColor = Colors.red;
    }

    return SizedBox(
      height: 120,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            PieChartSectionData(
              value: used > 0 ? used : 0.001,
              color: usedColor,
              title: used > 0 ? 'Usado' : '',
              radius: 20,
              titleStyle: const TextStyle(fontSize: 9, color: Colors.white),
            ),
            PieChartSectionData(
              value: free > 0 ? free : 0.001,
              color: Colors.grey[200]!,
              title: free > 0 ? 'Livre' : '',
              radius: 20,
              titleStyle: TextStyle(fontSize: 9, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeController = AppModeController.instance;

    return AnimatedBuilder(
      animation: modeController,
      builder: (context, _) {
        final mode = modeController.mode;
        final isSimple = mode == AppMode.simple;
        final isUltra = mode == AppMode.ultra;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cartoes'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openCardForm(),
            icon: const Icon(Icons.add),
            label: const Text('Novo cartao'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (isSimple)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Detalhes de cartoes sao mais uteis no modo ultra.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _cards.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final card = _cards[index];

                          return Dismissible(
                            key: ValueKey(card.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(card),
                            onDismissed: (_) async {
                              await _cardsRepository.remove(card.id);
                              await _loadData();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Cartao excluido com sucesso'),
                                ),
                              );
                            },
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _openCardForm(initial: card),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                card.name,
                                                style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${card.bankName} • ${_cardTypeLabel(card.type)} • Vencimento dia ${card.dueDay}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isUltra &&
                                            card.limit != null)
                                          _buildDonutChart(card),
                                      ],
                                    ),
                                    if (isUltra && card.limit != null)
                                      _buildLimitBar(card),
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
