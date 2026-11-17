import '../../../app/ledger.dart';
import '../../../core/models/year_month.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/monthly_history.dart';
import '../../cards/domain/invoice.dart';
import '../../categories/domain/category_tree.dart';
import '../../cards/domain/payment_card.dart';
import '../../forecast/domain/forecast.dart';
import '../../forecast/domain/invoice_timeline.dart';
import '../../transactions/domain/transaction.dart';

/// Fatura atual de um cartão (a não quitada mais antiga) com o uso do limite.
class InvoiceRow {
  const InvoiceRow({
    required this.invoice,
    required this.status,
    required this.usedCents,
  });

  final Invoice invoice;
  final InvoiceStatus status;
  final int usedCents;
}

/// Conta com saldo negativo previsto.
class NegativeAccount {
  const NegativeAccount({required this.name, required this.date});

  final String name;
  final DateTime date;
}

/// Gasto do mês por categoria. `name` já resolvido ("Sem categoria" quando nulo).
/// Ultra: `children` tem as subcategorias com gasto e, se houver, 'Sem subcategoria'
/// (gasto direto na raiz, com `id` igual ao da raiz).
class CategoryRow {
  const CategoryRow({
    required this.name,
    required this.cents,
    this.id,
    this.children = const [],
  });

  final String? id;
  final String name;
  final int cents;
  final List<CategoryRow> children;
}

/// Números do painel, calculados uma vez por build a partir do [Ledger].
class DashboardSummary {
  const DashboardSummary({
    required this.currentCents,
    required this.payableCents,
    required this.openInvoicesCents,
    required this.endOfMonthCents,
    required this.firstNegativeDate,
    required this.negativeAccounts,
    required this.invoices,
    required this.upcoming,
    required this.categories,
    required this.attention,
    this.balanceTrend,
    this.balanceDelta,
    this.monthExpenseCents,
    this.monthExpenseDelta,
    this.expenseTrend,
    this.netWorthCents,
    this.netWorthDelta,
    this.netWorthTrend,
  });

  final int currentCents;

  /// Saídas com data até hoje + 30 dias, sem transferências (valor positivo).
  final int payableCents;
  final int openInvoicesCents;
  final int endOfMonthCents;
  final DateTime? firstNegativeDate;
  final List<NegativeAccount> negativeAccounts;
  final List<InvoiceRow> invoices;
  final List<Transaction> upcoming;
  final List<CategoryRow> categories;

  /// Faturas dos próximos 60 dias sem saldo previsto na conta de pagamento (§5.9).
  final List<InvoiceDue> attention;

  /// Ultra: saldo fim de mês dos últimos 6 meses (sparkline) e variação vs. mês anterior.
  /// Simples: `null` (sem delta nem sparkline).
  final List<int>? balanceTrend;
  final double? balanceDelta;

  /// Ultra: gasto do mês até hoje, variação vs. mesmo período do mês anterior e gasto dos 6 meses.
  final int? monthExpenseCents;
  final double? monthExpenseDelta;
  final List<int>? expenseTrend;

  /// Ultra: patrimônio líquido de hoje, variação vs. mês anterior e `netCents` dos 6 últimos meses.
  /// Simples: `null`.
  final int? netWorthCents;
  final double? netWorthDelta;
  final List<int>? netWorthTrend;

  /// Simples: 8 vencimentos e 3 categorias. Ultra: 15 e 8.
  factory DashboardSummary.of(Ledger ledger, {required bool ultra}) {
    final today = ledger.today;
    final forecast = ledger.forecast;

    final payLimit = DateTime(today.year, today.month, today.day + 30);
    var payable = 0;
    for (final e in forecast.events) {
      if (e.amountCents < 0 &&
          e.kind != ForecastEventKind.transfer &&
          !e.date.isAfter(payLimit)) {
        payable -= e.amountCents;
      }
    }

    var openInvoices = 0;
    final invoices = <InvoiceRow>[];
    for (final card in ledger.cardsById.values) {
      if (card.kind != CardKind.credit || card.archived) {
        continue;
      }
      final invoice = ledger.currentInvoiceFor(card.id);
      if (invoice == null) {
        continue;
      }
      openInvoices += invoice.remainingCents;
      invoices.add(
        InvoiceRow(
          invoice: invoice,
          status: invoice.statusOn(today),
          usedCents: ledger.usedLimitFor(card.id),
        ),
      );
    }
    invoices.sort((a, b) => a.invoice.dueDate.compareTo(b.invoice.dueDate));

    final accountsById = ledger.accountsById;
    final negativeAccounts = [
      for (final entry in forecast.accountNegativeDates.entries)
        NegativeAccount(
          name: _accountLabel(accountsById[entry.key]),
          date: entry.value,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final history = ultra ? ledger.monthlyHistory : null;
    final mtd = ultra ? ledger.expenseMonthToDate : null;
    final netHistory = ultra ? ledger.netWorthHistory : null;

    final month = YearMonth.fromDate(today);
    final direct = ledger.spendingFor(month);
    final spending =
        ledger
            .rolledSpendingFor(month)
            .entries
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return DashboardSummary(
      currentCents: forecast.currentTotalCents,
      payableCents: payable,
      openInvoicesCents: openInvoices,
      endOfMonthCents: forecast.months.first.endBalanceCents,
      firstNegativeDate: forecast.firstNegativeDate,
      negativeAccounts: negativeAccounts,
      invoices: invoices,
      upcoming: ledger.upcoming().take(ultra ? 15 : 8).toList(),
      categories: [
        for (final e in spending.take(ultra ? 8 : 3))
          CategoryRow(
            id: e.key,
            name: _categoryName(ledger, e.key),
            cents: e.value,
            children: ultra && e.key != null
                ? _childRows(ledger.categoryTree, e.key!, direct)
                : const [],
          ),
      ],
      attention: [
        for (final d in ledger.invoiceTimeline)
          if (d.needsAttention) d,
      ],
      balanceTrend: history?.map((m) => m.endBalanceCents).toList(),
      balanceDelta: history == null
          ? null
          : deltaRatio(
              history[history.length - 2].endBalanceCents,
              history.last.endBalanceCents,
            ),
      monthExpenseCents: mtd?.current,
      monthExpenseDelta: mtd == null
          ? null
          : deltaRatio(mtd.previous, mtd.current),
      expenseTrend: history?.map((m) => m.expenseCents).toList(),
      netWorthCents: netHistory?.last.netCents,
      netWorthDelta: netHistory == null
          ? null
          : deltaRatio(
              netHistory[netHistory.length - 2].netCents,
              netHistory.last.netCents,
            ),
      netWorthTrend: netHistory
          ?.skip(netHistory.length > 6 ? netHistory.length - 6 : 0)
          .map((p) => p.netCents)
          .toList(),
    );
  }

  static String _accountLabel(Account? account) {
    if (account == null) {
      return 'Conta';
    }
    return account.bankName.isEmpty
        ? account.name
        : '${account.name} (${account.bankName})';
  }

  static String _categoryName(Ledger ledger, String? id) {
    if (id == null) {
      return 'Sem categoria';
    }
    return ledger.categoriesById[id]?.name ?? 'Sem categoria';
  }

  /// Subcategorias com gasto direto > 0, mais 'Sem subcategoria' (gasto na raiz), por valor desc.
  /// Raiz sem filhas → vazio (sem chevron).
  static List<CategoryRow> _childRows(
    CategoryTree tree,
    String rootId,
    Map<String?, int> direct,
  ) {
    if (!tree.hasChildren(rootId)) {
      return const [];
    }
    final rows = [
      for (final child in tree.childrenOf(rootId))
        if ((direct[child.id] ?? 0) > 0)
          CategoryRow(id: child.id, name: child.name, cents: direct[child.id]!),
      if ((direct[rootId] ?? 0) > 0)
        CategoryRow(
          id: rootId,
          name: 'Sem subcategoria',
          cents: direct[rootId]!,
        ),
    ];
    return rows..sort((a, b) => b.cents.compareTo(a.cents));
  }
}
