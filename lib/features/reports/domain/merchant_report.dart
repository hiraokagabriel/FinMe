import '../../../core/models/year_month.dart';
import '../../../core/utils/text_normalize.dart';
import '../../categories/domain/category_tree.dart';
import '../../rules/domain/rule_engine.dart';
import '../../transactions/domain/transaction.dart';
import 'report_filter.dart';

/// Um estabelecimento no período: total, compras distintas e a última compra.
class MerchantTotal {
  const MerchantTotal({
    required this.key,
    required this.label,
    required this.totalCents,
    required this.purchaseCount,
    required this.lastDate,
    required this.categoryId,
  });

  /// Chave de agrupamento.
  final String key;

  /// `description` da transação mais recente do grupo.
  final String label;
  final int totalCents;

  /// Compras distintas: parcelas do mesmo `installmentGroupId` contam 1.
  final int purchaseCount;
  final DateTime lastDate;

  /// Da transação mais recente.
  final String? categoryId;

  /// Ticket médio (arredondado).
  int get averageCents => roundDiv(totalCents, purchaseCount);
}

/// Chave de agrupamento: `normalizeDescription(ruleSubject(t))`; vazia → `foldText(description)`.
/// [memo] guarda a chave normalizada por texto bruto dentro de uma chamada (normalizar é o caro).
String merchantKey(Transaction t, [Map<String, String>? memo]) {
  final raw = ruleSubject(t);
  final k = memo == null
      ? normalizeDescription(raw)
      : (memo[raw] ??= normalizeDescription(raw));
  return k.isEmpty ? foldText(t.description) : k;
}

/// Estabelecimentos com `reportFlowOf == f.flow`, escopo de `matchesReportScope` e mês em [from, to].
/// Lançamento sem provisionar com data depois de [today] fica fora.
/// Ordem: total desc, compras desc, key asc.
List<MerchantTotal> topMerchants(
  Iterable<Transaction> txs,
  ReportFilter f, {
  required YearMonth from,
  required YearMonth to,
  required CategoryTree tree,
  required DateTime today,
}) {
  final memo = <String, String>{};
  final groups = <String, _MerchantAcc>{};
  for (final t in txs) {
    if (reportFlowOf(t) != f.flow || isFutureUnplanned(t, today)) {
      continue;
    }
    final month = YearMonth.fromDate(t.date);
    if (month < from || month > to || !matchesReportScope(t, f, tree)) {
      continue;
    }
    groups.putIfAbsent(merchantKey(t, memo), () => _MerchantAcc(t)).add(t);
  }
  final result = [for (final e in groups.entries) e.value.toTotal(e.key)];
  result.sort((a, b) {
    final byTotal = b.totalCents.compareTo(a.totalCents);
    if (byTotal != 0) {
      return byTotal;
    }
    final byCount = b.purchaseCount.compareTo(a.purchaseCount);
    return byCount != 0 ? byCount : a.key.compareTo(b.key);
  });
  return result;
}

class _MerchantAcc {
  _MerchantAcc(this._latest);

  Transaction _latest;
  int _totalCents = 0;
  int _singles = 0;
  final Set<String> _installmentGroups = {};

  void add(Transaction t) {
    _totalCents += t.amountCents;
    final groupId = t.installmentGroupId;
    if (groupId == null) {
      _singles++;
    } else {
      _installmentGroups.add(groupId);
    }
    if (_isNewer(t, _latest)) {
      _latest = t;
    }
  }

  MerchantTotal toTotal(String key) => MerchantTotal(
    key: key,
    label: _latest.description,
    totalCents: _totalCents,
    purchaseCount: _singles + _installmentGroups.length,
    lastDate: _latest.date,
    categoryId: _latest.categoryId,
  );

  /// Mais recente: maior data; empate → maior id.
  static bool _isNewer(Transaction a, Transaction b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate > 0 : a.id.compareTo(b.id) > 0;
  }
}
