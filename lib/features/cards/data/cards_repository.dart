import '../domain/card_entity.dart';
import '../domain/card_type.dart';

abstract class CardsRepository {
  Future<List<CardEntity>> getAll();
}

class InMemoryCardsRepository implements CardsRepository {
  InMemoryCardsRepository();

  final List<CardEntity> _cards = [
    const CardEntity(
      id: 'card_1',
      name: 'Cartão Principal',
      bankName: 'Banco A',
      type: CardType.credit,
      dueDay: 10,
      limit: 10000,
    ),
    const CardEntity(
      id: 'card_2',
      name: 'Cartão Secundário',
      bankName: 'Banco B',
      type: CardType.credit,
      dueDay: 20,
      limit: 5000,
    ),
  ];

  @override
  Future<List<CardEntity>> getAll() async {
    return _cards;
  }
}
