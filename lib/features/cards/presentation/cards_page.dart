import 'package:flutter/material.dart';

import '../data/cards_repository.dart';
import '../domain/card_entity.dart';
import '../domain/card_type.dart';

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
    _cardsRepository = InMemoryCardsRepository();
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
        return 'Crédito';
      case CardType.debit:
        return 'Débito';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _cards.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final card = _cards[index];
                return ListTile(
                  title: Text(card.name),
                  subtitle: Text(
                    '${card.bankName} • ${_cardTypeLabel(card.type)} • Vencimento dia ${card.dueDay}',
                  ),
                  trailing: card.limit != null
                      ? Text(
                          'Limite R\$ ${card.limit!.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
