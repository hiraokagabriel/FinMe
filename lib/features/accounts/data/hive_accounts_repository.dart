import 'package:hive/hive.dart';
import '../domain/account_entity.dart';
import 'account_model.dart';
import 'accounts_repository.dart';

class HiveAccountsRepository implements AccountsRepository {
  final Box<AccountModel> _box;

  HiveAccountsRepository(this._box);

  @override
  List<AccountEntity> getAll() =>
      _box.values.map((m) => m.toEntity()).toList()
        ..sort((a, b) {
          if (a.isDefault) return -1;
          if (b.isDefault) return 1;
          return a.name.compareTo(b.name);
        });

  @override
  AccountEntity? getById(String id) => _box.get(id)?.toEntity();

  @override
  Future<void> save(AccountEntity account) async {
    await _box.put(account.id, AccountModel.fromEntity(account));
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> setDefault(String id) async {
    for (final key in _box.keys) {
      final m = _box.get(key);
      if (m == null) continue;
      final updated = AccountModel(
        id: m.id,
        name: m.name,
        typeIndex: m.typeIndex,
        initialBalance: m.initialBalance,
        colorValue: m.colorValue,
        isDefault: m.id == id,
      );
      await _box.put(key, updated);
    }
  }
}
