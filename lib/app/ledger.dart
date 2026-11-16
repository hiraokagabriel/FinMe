import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/year_month.dart';
import '../core/services/collection_repository.dart';
import '../core/services/settings_controller.dart';
import '../core/utils/date_utils.dart';
import '../features/accounts/domain/account.dart';
import '../features/accounts/domain/balances.dart' as balances;
import '../features/accounts/domain/monthly_history.dart' as history;
import '../features/cards/domain/card_insights.dart' as insights;
import '../features/cards/domain/invoice.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/categories/domain/category_spending.dart';
import '../features/debts/domain/debt.dart';
import '../features/debts/domain/debt_math.dart' as debt_math;
import '../features/net_worth/domain/asset.dart';
import '../features/net_worth/domain/net_worth.dart' as net_worth;
import '../features/categories/domain/transaction_category.dart';
import '../features/categories/domain/category_tree.dart';
import '../features/forecast/domain/forecast.dart';
import '../features/forecast/domain/invoice_timeline.dart' as timeline;
import '../features/forecast/domain/spendable.dart' as spend;
import '../features/goals/domain/goal.dart';
import '../features/goals/domain/goal_math.dart' as goal_math;
import '../features/importing/domain/categorizer.dart';
import '../features/importing/domain/category_history.dart';
import '../features/importing/domain/merchant_dictionary.dart';
import '../features/recurring/domain/recurrence.dart';
import '../features/recurring/domain/recurring_rule.dart';
import '../features/rules/domain/transaction_rule.dart';
import '../features/transactions/domain/tags.dart';
import '../features/transactions/domain/transaction.dart';

/// Visões calculadas sobre os repositórios. Getters são preguiçosos e memoizados;
/// qualquer mudança em repo ou configurações zera o cache e notifica.
/// Virada de dia zera o cache e roda [onDayChanged] numa microtask (fora do build).
class Ledger extends ChangeNotifier {
  Ledger({
    required this.accounts,
    required this.cards,
    required this.categories,
    required this.transactions,
    required this.recurring,
    required this.settings,
    required this.clock,
    this.rules,
    this.dictionary,
    this.goals,
    this.assets,
    this.debts,
    this.onDayChanged,
    this.scheduleMidnightTimer = true,
  }) {
    _cacheDay = dateOnly(clock());
    for (final source in _sources) {
      source.addListener(_invalidate);
    }
    if (scheduleMidnightTimer) {
      _scheduleMidnight();
    }
  }

  final CollectionRepository<Account> accounts;
  final CollectionRepository<PaymentCard> cards;
  final CollectionRepository<TransactionCategory> categories;
  final CollectionRepository<Transaction> transactions;
  final CollectionRepository<RecurringRule> recurring;
  final SettingsController settings;
  final DateTime Function() clock;

  /// Fase 8: opcionais para que testes que constroem o Ledger direto sigam válidos (null = vazio).
  final CollectionRepository<TransactionRule>? rules;
  final CollectionRepository<DictionaryEntry>? dictionary;

  /// Fase 10: opcional como as anteriores (null = sem metas).
  final CollectionRepository<Goal>? goals;

  /// Fase 11: opcionais como as anteriores (null = vazio). `debts` também entra na previsão (SPEC §5.25 regra 6).
  final CollectionRepository<Asset>? assets;
  final CollectionRepository<Debt>? debts;

  /// Horizonte do patrimônio líquido (SPEC §5.26): meses terminando no mês de hoje.
  static const int netWorthMonths = 24;

  /// Chamado na virada de dia (bootstrap passa `materializeRecurring`). Evita import circular.
  final Future<void> Function()? onDayChanged;

  /// Falso em teste: sem ele não sobra `Timer` pendente. Bootstrap mantém true.
  final bool scheduleMidnightTimer;

  late DateTime _cacheDay;
  Timer? _midnightTimer;
  bool _disposed = false;
  Map<String, int>? _balances;
  Map<String, PaymentCard>? _cardsById;
  Map<String, Account>? _accountsById;
  Map<String, TransactionCategory>? _categoriesById;
  Map<String, List<Transaction>>? _txByCard;
  Map<String, List<Transaction>>? _projectedByCard;
  Forecast? _forecast;
  final _invoices = <String, List<Invoice>>{};
  final _spending = <YearMonth, Map<String?, int>>{};
  final _upcoming = <int, List<Transaction>>{};
  List<timeline.InvoiceDue>? _invoiceTimeline;
  List<insights.CardPurchaseOption>? _bestCards;
  List<insights.InstallmentCommitment>? _installments;
  List<PaymentCard>? _cardsNoAccount;
  List<history.MonthSnapshot>? _history;
  ({int current, int previous})? _expenseMtd;
  Categorizer? _categorizer;
  CategoryTree? _categoryTree;
  final _rolled = <YearMonth, Map<String?, int>>{};
  Map<String, int>? _reserved;
  spend.SpendableToday? _spendable;
  List<String>? _allTags;
  List<net_worth.NetWorthPoint>? _netWorth;
  List<debt_math.PersonDebtSummary>? _debtsByPerson;
  List<String>? _debtPeople;

  List<Listenable> get _sources => [
    accounts,
    cards,
    categories,
    transactions,
    recurring,
    settings,
    ?rules,
    ?dictionary,
    ?goals,
    ?assets,
    ?debts,
  ];

  /// Dia do cache. Se o relógio andou para outro dia, invalida e agenda [onDayChanged].
  void _ensureFresh() {
    final day = dateOnly(clock());
    if (isSameDay(day, _cacheDay)) {
      return;
    }
    _cacheDay = day;
    _clearCache();
    scheduleMicrotask(() {
      if (!_disposed) {
        notifyListeners();
      }
    });
    final callback = onDayChanged;
    if (callback != null) {
      scheduleMicrotask(
        () => callback().catchError((Object e, StackTrace st) {
          debugPrint('Ledger: falha na virada de dia: $e\n$st');
        }),
      );
    }
  }

  /// Vira o dia mesmo sem leitura: timer até a meia-noite (+1s), que se reagenda.
  void _scheduleMidnight() {
    final now = clock();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      midnight.difference(now) + const Duration(seconds: 1),
      () {
        _ensureFresh();
        _scheduleMidnight();
      },
    );
  }

  DateTime get today {
    _ensureFresh();
    return _cacheDay;
  }

  Map<String, int> get accountBalances {
    _ensureFresh();
    return _balances ??= balances.accountBalances(
      accounts: accounts.all,
      cards: cards.all,
      transactions: transactions.all,
    );
  }

  Map<String, PaymentCard> get cardsById {
    _ensureFresh();
    return _cardsById ??= {for (final c in cards.all) c.id: c};
  }

  Map<String, Account> get accountsById {
    _ensureFresh();
    return _accountsById ??= {for (final a in accounts.all) a.id: a};
  }

  Map<String, TransactionCategory> get categoriesById {
    _ensureFresh();
    return _categoriesById ??= {for (final c in categories.all) c.id: c};
  }

  /// Faturas do cartão, incluindo parcelas futuras e recorrências de cartão projetadas.
  List<Invoice> invoicesFor(String cardId) {
    _ensureFresh();
    final card = cardsById[cardId];
    if (card == null) {
      return const [];
    }
    return _invoices[cardId] ??= InvoiceService.build(
      card: card,
      transactions: _cardTransactions[cardId] ?? const [],
      projected: _cardProjections[cardId] ?? const [],
    );
  }

  int usedLimitFor(String cardId) =>
      InvoiceService.usedLimitCents(invoicesFor(cardId), today);

  Invoice? currentInvoiceFor(String cardId) =>
      InvoiceService.currentInvoice(invoicesFor(cardId), today);

  /// Horizonte mínimo (dias) da linha do tempo de faturas; a previsão sempre cobre.
  static const int invoiceTimelineDays = 60;

  Forecast get forecast {
    _ensureFresh();
    return _forecast ??= ForecastService.compute(
      accounts: accounts.all,
      cards: cards.all,
      transactions: transactions.all,
      recurring: recurring.all,
      today: today,
      months: settings.value.forecastMonths,
      minDays: invoiceTimelineDays,
      extraEvents: debt_math.debtForecastEvents(debts?.all ?? const []),
    );
  }

  /// Patrimônio líquido dos últimos [netWorthMonths] meses; o último ponto é hoje (SPEC §5.26).
  List<net_worth.NetWorthPoint> get netWorthHistory {
    _ensureFresh();
    return _netWorth ??= net_worth.netWorthHistory(
      accounts: accounts.all,
      cards: cards.all,
      transactions: transactions.all,
      assets: assets?.all ?? const [],
      debts: debts?.all ?? const [],
      today: today,
      months: netWorthMonths,
    );
  }

  /// Devo / me devem agrupados por pessoa (SPEC §5.25). Vazio sem `debts`.
  List<debt_math.PersonDebtSummary> get debtsByPerson {
    _ensureFresh();
    return _debtsByPerson ??= debt_math.debtsByPerson(debts?.all ?? const []);
  }

  /// Sugestões do campo Pessoa (SPEC §5.25), quitadas inclusive.
  List<String> get debtPeople {
    _ensureFresh();
    return _debtPeople ??= debt_math.debtPeople(debts?.all ?? const []);
  }

  /// Faturas de todos os cartões de crédito (inclui arquivados; ids batem com `forecast.events`).
  List<Invoice> get _creditInvoices => [
    for (final c in cards.all)
      if (c.kind == CardKind.credit) ...invoicesFor(c.id),
  ];

  /// Vencimentos de fatura em 60 dias com saldo-após da conta de pagamento.
  List<timeline.InvoiceDue> get invoiceTimeline {
    _ensureFresh();
    return _invoiceTimeline ??= timeline.invoiceTimeline(
      forecast: forecast,
      invoices: _creditInvoices,
      days: invoiceTimelineDays,
    );
  }

  /// Cartões de crédito ordenados por melhor opção de compra hoje.
  List<insights.CardPurchaseOption> get bestCardsToday {
    _ensureFresh();
    return _bestCards ??= insights.bestCardsToBuy(
      cards: cards.all,
      usedLimitByCard: {for (final c in cards.all) c.id: usedLimitFor(c.id)},
      today: today,
    );
  }

  /// Parcelas comprometidas nos próximos 12 meses, a partir do mês seguinte.
  List<insights.InstallmentCommitment> get installmentCommitments {
    _ensureFresh();
    return _installments ??= insights.installmentCommitments(
      invoices: _creditInvoices,
      from: YearMonth.fromDate(today).next(),
    );
  }

  /// Cartões sem conta de pagamento ativa (null, inexistente ou arquivada).
  List<PaymentCard> get cardsWithoutPaymentAccount {
    _ensureFresh();
    return _cardsNoAccount ??= insights.cardsWithoutPaymentAccount(cards.all, {
      for (final a in accounts.all)
        if (!a.archived) a.id,
    });
  }

  /// Últimos 6 meses até hoje (SPEC §5.10). Alimenta sparklines e deltas do Painel Ultra.
  List<history.MonthSnapshot> get monthlyHistory {
    _ensureFresh();
    return _history ??= history.monthlyHistory(
      accounts: accounts.all,
      cards: cards.all,
      transactions: transactions.all,
      today: today,
      months: 6,
    );
  }

  /// Gasto do mês até hoje e o mesmo período (até o mesmo dia) do mês anterior.
  ({int current, int previous}) get expenseMonthToDate {
    _ensureFresh();
    return _expenseMtd ??= (
      current: monthlyHistory.last.expenseCents,
      previous: history.expenseUntilDay(
        transactions.all,
        YearMonth.fromDate(today).prev(),
        today.day,
      ),
    );
  }

  /// Cascata de sugestão de categoria (SPEC §5.13). Recriada a cada mudança de repo.
  Categorizer get categorizer {
    _ensureFresh();
    return _categorizer ??= Categorizer(
      rules: rules?.all ?? const [],
      categories: categories.all,
      history: CategoryHistory.build(transactions.all),
      dictionary: dictionary?.all ?? const [],
    );
  }

  Map<String?, int> spendingFor(YearMonth month) {
    _ensureFresh();
    return _spending[month] ??= spendingByCategory(transactions.all, month);
  }

  /// Árvore de categorias (Fase 10). Recriada a cada mudança de categorias.
  CategoryTree get categoryTree {
    _ensureFresh();
    return _categoryTree ??= CategoryTree(categories.all);
  }

  /// Gasto do mês com subcategorias somadas na raiz (SPEC §5.20).
  Map<String?, int> rolledSpendingFor(YearMonth month) {
    _ensureFresh();
    return _rolled[month] ??= categoryTree.rollUp(spendingFor(month));
  }

  /// Reserva ativa por conta das metas (SPEC §5.22). Vazio sem `goals`.
  Map<String, int> get reservedByAccount {
    _ensureFresh();
    return _reserved ??= goal_math.reservedByAccount(goals?.all ?? const []);
  }

  /// "Posso gastar hoje" até a próxima receita ou fim do mês (SPEC §5.23).
  spend.SpendableToday get spendableToday {
    _ensureFresh();
    return _spendable ??= spend.spendableToday(
      forecast: forecast,
      recurring: recurring.all,
      accountsById: accountsById,
      reservedByAccount: reservedByAccount,
      horizonEnd: ForecastService.horizonEnd(
        today: today,
        months: settings.value.forecastMonths,
        minDays: invoiceTimelineDays,
      ),
    );
  }

  /// Tags de todas as transações, das mais usadas às menos usadas (SPEC §5.21).
  List<String> get allTags {
    _ensureFresh();
    return _allTags ??= List.unmodifiable([
      for (final u in tagUsage(transactions.all)) u.tag,
    ]);
  }

  /// Saídas de conta em [days] dias: despesas provisionadas (inclusive atrasadas e boletos)
  /// e ocorrências projetadas de despesas de conta. Memoizado por `days`; lista imutável.
  List<Transaction> upcoming({int days = 30}) {
    _ensureFresh();
    return _upcoming[days] ??= List.unmodifiable(_computeUpcoming(days));
  }

  List<Transaction> _computeUpcoming(int days) {
    final now = today;
    final limit = DateTime(now.year, now.month, now.day + days);
    final existing = {for (final t in transactions.all) t.id};
    final list = <Transaction>[
      for (final t in transactions.all)
        if (t.isPlanned &&
            t.accountId != null &&
            t.type == TransactionType.expense &&
            !t.date.isAfter(limit))
          t,
      for (final r in recurring.all)
        if (r.cardId == null && r.type == TransactionType.expense)
          ...occurrenceTransactions(
            r,
            now,
            limit,
            existing,
            forProjection: true,
          ),
    ];
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Map<String, List<Transaction>> get _cardTransactions =>
      _txByCard ??= _groupByCard(transactions.all);

  Map<String, List<Transaction>> get _cardProjections =>
      _projectedByCard ??= _groupByCard(_projectedCardOccurrences());

  /// Ocorrências de recorrências de cartão de hoje até o mesmo fim da previsão (`forecast`).
  List<Transaction> _projectedCardOccurrences() {
    final now = today;
    final end = ForecastService.horizonEnd(
      today: now,
      months: settings.value.forecastMonths,
      minDays: invoiceTimelineDays,
    );
    final existing = {for (final t in transactions.all) t.id};
    return [
      for (final r in recurring.all)
        if (r.cardId != null)
          ...occurrenceTransactions(r, now, end, existing, forProjection: true),
    ];
  }

  static Map<String, List<Transaction>> _groupByCard(
    Iterable<Transaction> list,
  ) {
    final map = <String, List<Transaction>>{};
    for (final t in list) {
      final cardId = t.cardId;
      if (cardId != null) {
        map.putIfAbsent(cardId, () => []).add(t);
      }
    }
    return map;
  }

  void _clearCache() {
    _balances = null;
    _cardsById = null;
    _accountsById = null;
    _categoriesById = null;
    _txByCard = null;
    _projectedByCard = null;
    _forecast = null;
    _invoices.clear();
    _spending.clear();
    _upcoming.clear();
    _invoiceTimeline = null;
    _bestCards = null;
    _installments = null;
    _cardsNoAccount = null;
    _history = null;
    _expenseMtd = null;
    _categorizer = null;
    _categoryTree = null;
    _rolled.clear();
    _reserved = null;
    _spendable = null;
    _allTags = null;
    _netWorth = null;
    _debtsByPerson = null;
    _debtPeople = null;
  }

  void _invalidate() {
    _clearCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _midnightTimer?.cancel();
    for (final source in _sources) {
      source.removeListener(_invalidate);
    }
    super.dispose();
  }
}
