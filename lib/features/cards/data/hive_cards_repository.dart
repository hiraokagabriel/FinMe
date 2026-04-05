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

  @override
  Future<void> add(CardEntity card) async {
    final model = CardModel.fromEntity(card);
    await _box.add(model);
  }

  @override
  Future<void> update(CardEntity card) async {
    final model = CardModel.fromEntity(card);
    final key = _findKeyById(card.id);
    if (key == null) return;
    await _box.put(key, model);
  }

  @override
  Future<void> remove(String id) async {
    final key = _findKeyById(id);
    if (key == null) return;
    await _box.delete(key);
  }

  dynamic _findKeyById(String id) {
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value != null && value.id == id) {
        return key;
      }
    }
    return null;
  }
}
