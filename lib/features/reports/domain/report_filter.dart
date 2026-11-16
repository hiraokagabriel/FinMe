import '../../../core/models/year_month.dart';
import '../../categories/domain/category_tree.dart';
import '../../transactions/domain/tags.dart';
import '../../transactions/domain/transaction.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o campo; `null` limpa; valor troca.
const Object _keep = Object();

enum ReportKind {
  categoryComparison,
  trend,
  pivot,
  heatmap,
  topMerchants,
  fixedVariable,
  netWorth,
} // ordem da lista no Ultra

const List<ReportKind> kUltraReports = ReportKind.values;
const List<ReportKind> kSimpleReports = [
  ReportKind.trend,
  ReportKind.topMerchants,
  ReportKind.categoryComparison,
];

String reportKindLabel(ReportKind k) => switch (k) {
  ReportKind.categoryComparison => 'Comparativo por categoria',
  ReportKind.trend => 'Tendência',
  ReportKind.pivot => 'Categoria × mês',
  ReportKind.heatmap => 'Gasto por dia',
  ReportKind.topMerchants => 'Top estabelecimentos',
  ReportKind.fixedVariable => 'Fixo × variável',
  ReportKind.netWorth => 'Evolução do patrimônio',
};

String reportKindSlug(ReportKind k) => switch (k) {
  ReportKind.categoryComparison => 'comparativo-categorias',
  ReportKind.trend => 'tendencia',
  ReportKind.pivot => 'categoria-mes',
  ReportKind.heatmap => 'gasto-por-dia',
  ReportKind.topMerchants => 'estabelecimentos',
  ReportKind.fixedVariable => 'fixo-variavel',
  ReportKind.netWorth => 'patrimonio',
};

enum ReportPeriodPreset { last3, last6, last12, thisYear, lastYear, custom }

String reportPeriodLabel(ReportPeriodPreset p) => switch (p) {
  ReportPeriodPreset.last3 => '3 meses',
  ReportPeriodPreset.last6 => '6 meses',
  ReportPeriodPreset.last12 => '12 meses',
  ReportPeriodPreset.thisYear => 'Ano atual',
  ReportPeriodPreset.lastYear => 'Ano anterior',
  ReportPeriodPreset.custom => 'Personalizado',
};

enum ReportFlow { expense, income }

const int kReportMaxMonths = 60;

/// Filtros globais dos relatórios. Sets copiados e imutáveis no construtor
/// (por isso não é `const`). Igualdade por conteúdo; sets comparados como conjuntos.
class ReportFilter {
  ReportFilter({
    this.preset = ReportPeriodPreset.last12,
    this.customFrom,
    this.customTo,
    Set<String> accountIds = const {},
    Set<String> cardIds = const {},
    Set<String> categoryIds = const {},
    Set<String> tagKeys = const {},
    this.flow = ReportFlow.expense,
    this.includePlanned = false,
  }) : accountIds = Set.unmodifiable(accountIds),
       cardIds = Set.unmodifiable(cardIds),
       categoryIds = Set.unmodifiable(categoryIds),
       tagKeys = Set.unmodifiable(tagKeys);

  final ReportPeriodPreset preset;

  /// Só valem com preset custom.
  final YearMonth? customFrom, customTo;

  /// Vazios = todas as contas e cartões.
  final Set<String> accountIds, cardIds;

  /// Vazio = todas; raiz selecionada inclui as filhas.
  final Set<String> categoryIds;

  /// Já em `tagKey`; vazio = sem filtro; "tem alguma" (hasAnyTag).
  final Set<String> tagKeys;

  /// Despesas (padrão) ou receitas.
  final ReportFlow flow;

  /// Padrão false.
  final bool includePlanned;

  ReportFilter copyWith({
    ReportPeriodPreset? preset,
    Object? customFrom = _keep,
    Object? customTo = _keep,
    Set<String>? accountIds,
    Set<String>? cardIds,
    Set<String>? categoryIds,
    Set<String>? tagKeys,
    ReportFlow? flow,
    bool? includePlanned,
  }) => ReportFilter(
    preset: preset ?? this.preset,
    customFrom: identical(customFrom, _keep)
        ? this.customFrom
        : customFrom as YearMonth?,
    customTo: identical(customTo, _keep)
        ? this.customTo
        : customTo as YearMonth?,
    accountIds: accountIds ?? this.accountIds,
    cardIds: cardIds ?? this.cardIds,
    categoryIds: categoryIds ?? this.categoryIds,
    tagKeys: tagKeys ?? this.tagKeys,
    flow: flow ?? this.flow,
    includePlanned: includePlanned ?? this.includePlanned,
  );

  /// Mesmo período; o resto volta ao padrão (Modo Simples).
  ReportFilter get periodOnly =>
      ReportFilter(preset: preset, customFrom: customFrom, customTo: customTo);

  /// Igual a este, sem categorias. Usado no lado do fluxo que não é o das categorias marcadas.
  ReportFilter get withoutCategories => copyWith(categoryIds: const {});

  bool get hasScopeFilters =>
      accountIds.isNotEmpty ||
      cardIds.isNotEmpty ||
      categoryIds.isNotEmpty ||
      tagKeys.isNotEmpty ||
      flow != ReportFlow.expense ||
      includePlanned;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportFilter &&
          other.preset == preset &&
          other.customFrom == customFrom &&
          other.customTo == customTo &&
          other.flow == flow &&
          other.includePlanned == includePlanned &&
          _sameSet(other.accountIds, accountIds) &&
          _sameSet(other.cardIds, cardIds) &&
          _sameSet(other.categoryIds, categoryIds) &&
          _sameSet(other.tagKeys, tagKeys);

  @override
  int get hashCode => Object.hash(
    preset,
    customFrom,
    customTo,
    flow,
    includePlanned,
    Object.hashAllUnordered(accountIds),
    Object.hashAllUnordered(cardIds),
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(tagKeys),
  );

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

typedef ReportRange = ({YearMonth from, YearMonth to});

/// Período efetivo. Meses futuros são permitidos (só têm provisionados).
ReportRange resolveReportRange(ReportFilter f, DateTime today) {
  final cur = YearMonth.fromDate(today);
  final (from, to) = switch (f.preset) {
    ReportPeriodPreset.last3 => (cur.addMonths(-2), cur),
    ReportPeriodPreset.last6 => (cur.addMonths(-5), cur),
    ReportPeriodPreset.last12 => (cur.addMonths(-11), cur),
    ReportPeriodPreset.thisYear => (YearMonth(cur.year, 1), cur),
    ReportPeriodPreset.lastYear => (
      YearMonth(cur.year - 1, 1),
      YearMonth(cur.year - 1, 12),
    ),
    ReportPeriodPreset.custom => (
      f.customFrom ?? cur.addMonths(-11),
      f.customTo ?? cur,
    ),
  };
  final (a, b) = from > to ? (to, from) : (from, to);
  final capped = _monthCount(a, b) > kReportMaxMonths
      ? b.addMonths(1 - kReportMaxMonths)
      : a;
  return (from: capped, to: b);
}

int _monthCount(YearMonth a, YearMonth b) =>
    (b.year - a.year) * 12 + (b.month - a.month) + 1;

/// from..to inclusive, em ordem cronológica.
List<YearMonth> monthsOf(ReportRange r) => [
  for (var m = r.from; m <= r.to; m = m.next()) m,
];

/// Despesa (qualquer conta ou cartão) → expense; receita em conta → income;
/// receita em cartão (estorno), transfer e invoicePayment → null (fora dos relatórios).
ReportFlow? reportFlowOf(Transaction t) => switch (t.type) {
  TransactionType.expense => ReportFlow.expense,
  TransactionType.income => t.accountId != null ? ReportFlow.income : null,
  TransactionType.transfer || TransactionType.invoicePayment => null,
};

/// Escopo (sem período e sem flow): provisionado só com includePlanned, contas/cartões,
/// categorias (raiz inclui filhas) e tags.
bool matchesReportScope(Transaction t, ReportFilter f, CategoryTree tree) {
  if (t.isPlanned && !f.includePlanned) {
    return false;
  }
  if (f.accountIds.isNotEmpty || f.cardIds.isNotEmpty) {
    final byAccount = t.accountId != null && f.accountIds.contains(t.accountId);
    final byCard = t.cardId != null && f.cardIds.contains(t.cardId);
    if (!byAccount && !byCard) {
      return false;
    }
  }
  if (f.categoryIds.isNotEmpty) {
    final id = t.categoryId;
    if (id == null ||
        !(f.categoryIds.contains(id) ||
            f.categoryIds.contains(tree.rootOf(id)))) {
      return false;
    }
  }
  return hasAnyTag(t, f.tagKeys);
}

/// Lançamento sem provisionar com data depois de [today]: fica fora até acontecer.
/// `date` é meia-noite, então qualquer hora de [today] serve.
bool isFutureUnplanned(Transaction t, DateTime today) =>
    !t.isPlanned && t.date.isAfter(today);

/// Divisão inteira arredondada (meio para longe de zero). Exige b > 0.
int roundDiv(int a, int b) =>
    a >= 0 ? (2 * a + b) ~/ (2 * b) : -((-2 * a + b) ~/ (2 * b));

/// Rótulo da categoria. [isDirect] = gasto direto na raiz (linha "(sem subcategoria)").
String reportCategoryLabel(
  String? id,
  CategoryTree tree, {
  bool isDirect = false,
}) {
  if (id == null) {
    return 'Sem categoria';
  }
  final label = tree.label(id);
  if (label.isEmpty) {
    return 'Categoria removida';
  }
  return isDirect ? '$label$kCategoryPathSeparator(sem subcategoria)' : label;
}

/// Rótulos dos filtros ativos que o relatório ignora, em ordem fixa.
/// Período nunca entra.
List<String> ignoredFilters(ReportKind k, ReportFilter f) {
  final scopeIgnored = k == ReportKind.netWorth;
  final flowIgnored = switch (k) {
    ReportKind.trend ||
    ReportKind.heatmap ||
    ReportKind.fixedVariable ||
    ReportKind.netWorth => true,
    _ => false,
  };
  // Tendência: categorias valem só no lado do fluxo do filtro. Despesa-only com flow receita: ignoradas.
  final expenseOnly = k == ReportKind.heatmap || k == ReportKind.fixedVariable;
  final categoriesIgnored =
      scopeIgnored ||
      k == ReportKind.trend ||
      (expenseOnly && f.flow == ReportFlow.income);
  return [
    if (scopeIgnored && (f.accountIds.isNotEmpty || f.cardIds.isNotEmpty))
      'contas e cartões',
    if (categoriesIgnored && f.categoryIds.isNotEmpty) 'categorias',
    if (scopeIgnored && f.tagKeys.isNotEmpty) 'tags',
    if (flowIgnored && f.flow != ReportFlow.expense) 'tipo',
    if (scopeIgnored && f.includePlanned) 'provisionados',
  ];
}
