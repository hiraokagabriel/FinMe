import 'package:hive/hive.dart';

import 'card_model.dart';
import '../domain/card_entity.dart';
import 'cards_repository.dart';

class HiveCardsRepository implements CardsRepository {
  HiveCardsRepository(this._box);

  final Box<CardModel> _box;

  @override
  Future<List<CardEntity>> getAll() async {
    return _box.values.map((m) => m.toEntity()).toList(growable: false);
  }
}
