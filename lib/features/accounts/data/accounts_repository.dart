import '../domain/account_entity.dart';

abstract class AccountsRepository {
  List<AccountEntity> getAll();
  AccountEntity? getById(String id);
  Future<void> save(AccountEntity account);
  Future<void> delete(String id);
  Future<void> setDefault(String id);
}
