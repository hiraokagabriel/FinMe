import '../domain/card_entity.dart';

abstract class CardsRepository {
  Future<List<CardEntity>> getAll();
  Future<void> add(CardEntity card);
  Future<void> update(CardEntity card);
  Future<void> remove(String id);
}

class InMemoryCardsRepository implements CardsRepository {
  InMemoryCardsRepository();

  final List<CardEntity> _cards = [];

  @override
  Future<List<CardEntity>> getAll() async {
    return List.unmodifiable(_cards);
  }

  @override
  Future<void> add(CardEntity card) async {
    _cards.add(card);
  }

  @override
  Future<void> update(CardEntity card) async {
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index == -1) return;
    _cards[index] = card;
  }

  @override
  Future<void> remove(String id) async {
    _cards.removeWhere((c) => c.id == id);
  }
}
