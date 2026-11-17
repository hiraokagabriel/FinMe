import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/collection_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/debt.dart';
import '../domain/debt_math.dart';

/// Mantém pagamentos de dívida coerentes com as transações de quitação (SPEC §9.12).
/// Editar ou excluir a transação ajusta o pagamento; `_known` são os ids ligados na última sincronização,
/// para que um transactionId órfão (backup) nunca apague pagamento.
class DebtTransactionSync {
  DebtTransactionSync({required this.transactions, required this.debts}) {
    _known = _linked();
    transactions.addListener(_onTransactionsChanged);
    debts.addListener(_onDebtsChanged);
  }

  final CollectionRepository<Transaction> transactions;
  final CollectionRepository<Debt> debts;

  late Set<String> _known;
  int _suspended = 0;

  /// Executa [action] sem sincronizar (import de backup, apagar tudo); depois recalcula `_known`.
  Future<T> suspendDuring<T>(Future<T> Function() action) async {
    _suspended++;
    try {
      return await action();
    } finally {
      _suspended--;
      _known = _linked();
    }
  }

  void dispose() {
    transactions.removeListener(_onTransactionsChanged);
    debts.removeListener(_onDebtsChanged);
  }

  Set<String> _linked() =>
      linkedTransactionIds(debts.all, (id) => transactions.byId(id) != null);

  void _onTransactionsChanged() {
    if (_suspended > 0) {
      return;
    }
    unawaited(_sync());
  }

  void _onDebtsChanged() {
    _known = _linked();
  }

  Future<void> _sync() async {
    final changed = syncDebtsWithTransactions(
      debts.all,
      knownIds: _known,
      lookup: transactions.byId,
    );
    if (changed.isNotEmpty) {
      try {
        await debts.upsertAll(changed);
      } catch (error) {
        // _known fica como está: a próxima mudança tenta de novo.
        debugPrint('DebtTransactionSync: falha ao ajustar dívidas: $error');
        return;
      }
    }
    _known = _linked();
  }
}
