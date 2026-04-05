import 'package:flutter/material.dart';

import '../data/cards_repository.dart';
import '../domain/card_entity.dart';
import '../domain/card_type.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/repository_locator.dart';
import 'new_card_page.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late final CardsRepository _cardsRepository;
  List<CardEntity> _cards = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cardsRepository = RepositoryLocator.instance.cards;
    _loadData();
  }

  Future<void> _loadData() async {
    final cards = await _cardsRepository.getAll();
    setState(() {
      _cards = cards;
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
    final createdOrUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NewCardPage(initialCard: initial),
      ),
    );
    if (createdOrUpdated == true) {
      await _loadData();
    }
  }

  Future<bool?> _confirmDelete(CardEntity card) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir cartao'),
          content: Text(
            'Tem certeza que deseja excluir este cartao?\n\n${card.name}',
          ),
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

  @override
  Widget build(BuildContext context) {
    final modeController = AppModeController.instance;

    return AnimatedBuilder(
      animation: modeController,
      builder: (context, _) {
        final mode = modeController.mode;
        final isSimple = mode == AppMode.simple;

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
                        itemCount: _cards.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
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
                                horizontal: 16,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _openCardForm(initial: card),
                              title: Text(card.name),
                              subtitle: Text(
                                '${card.bankName} • ${_cardTypeLabel(card.type)} • Vencimento dia ${card.dueDay}',
                              ),
                              trailing: card.limit != null
                                  ? Text(
                                      'Limite R\$ ${card.limit!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
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
