import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/transaction_filters.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx(
  String id, {
  TransactionType type = TransactionType.expense,
  int cents = 1000,
  DateTime? date,
  String description = 'Mercado',
  String? accountId = 'acc_alfa',
  String? cardId,
  String? categoryId,
  TransactionStatus status = TransactionStatus.paid,
  bool boleto = false,
  String? notes,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date ?? DateTime(2026, 11, 10),
  description: description,
  accountId: accountId,
  cardId: cardId,
  categoryId: categoryId,
  status: status,
  isBoleto: boleto,
  notes: notes,
);

void main() {
  final nov = const YearMonth(2026, 11);

  test('visibleTransactions filtra por mês e ordena por data desc', () {
    final rows = visibleTransactions(
      [
        _tx('a', date: DateTime(2026, 11, 2)),
        _tx('b', date: DateTime(2026, 11, 20)),
        _tx('c', date: DateTime(2026, 10, 31)),
      ],
      nov,
      const TransactionFilter(),
    );
    expect(rows.map((t) => t.id), ['b', 'a']);
  });

  test('provisionados somem quando showPlanned é falso', () {
    final all = [_tx('paid'), _tx('plan', status: TransactionStatus.planned)];
    final rows = visibleTransactions(
      all,
      nov,
      const TransactionFilter(showPlanned: false),
    );
    expect(rows.map((t) => t.id), ['paid']);
  });

  test('busca é case-insensitive em descrição e notas', () {
    final all = [
      _tx('a', description: 'Supermercado'),
      _tx('b', description: 'Farmácia', notes: 'SUPER promo'),
      _tx('c', description: 'Padaria'),
    ];
    final rows = visibleTransactions(
      all,
      nov,
      const TransactionFilter(query: 'super'),
    );
    expect(rows.map((t) => t.id).toSet(), {'a', 'b'});
  });

  test('origem por conta e por cartão', () {
    final all = [
      _tx('conta'),
      _tx('cartao', accountId: null, cardId: 'card_x'),
    ];
    expect(
      visibleTransactions(
        all,
        nov,
        const TransactionFilter(origin: 'card:card_x'),
      ).map((t) => t.id),
      ['cartao'],
    );
    expect(
      visibleTransactions(
        all,
        nov,
        const TransactionFilter(origin: 'acc:acc_alfa'),
      ).map((t) => t.id),
      ['conta'],
    );
  });

  test('tipos são somados em OR; boleto usa isBoleto', () {
    final all = [
      _tx('despesa'),
      _tx('receita', type: TransactionType.income),
      _tx('boleto', boleto: true),
    ];
    final rows = visibleTransactions(
      all,
      nov,
      const TransactionFilter(
        kinds: {TxKindFilter.income, TxKindFilter.boleto},
      ),
    );
    expect(rows.map((t) => t.id).toSet(), {'receita', 'boleto'});
  });

  test('txTotals: despesas efetivas, provisionado (saída) e receitas', () {
    final totals = txTotals([
      _tx('d', cents: 500),
      _tx('p', cents: 300, status: TransactionStatus.planned),
      _tx('r', type: TransactionType.income, cents: 900),
      _tx('t', type: TransactionType.transfer, cents: 700),
    ]);
    expect(totals.expenses, 500);
    expect(totals.provisioned, 300);
    expect(totals.income, 900);
  });

  group('ordenação', () {
    // a: "Banana" 300 dia 2, b: "abacate" 100 dia 3, c: "Cenoura" 200 dia 1.
    final rows = [
      _tx(
        'a',
        description: 'Banana',
        cents: 300,
        date: DateTime(2026, 11, 2),
        accountId: 'acc_b',
        categoryId: 'cat_z',
      ),
      _tx(
        'b',
        description: 'abacate',
        cents: 100,
        date: DateTime(2026, 11, 3),
        accountId: 'acc_a',
        categoryId: 'cat_m',
      ),
      _tx(
        'c',
        description: 'Cenoura',
        cents: 200,
        date: DateTime(2026, 11, 1),
        accountId: 'acc_c',
        categoryId: 'cat_a',
      ),
    ];

    List<String> ids(TxSortColumn column, {required bool ascending}) =>
        sortTransactions(
          rows,
          (column: column, ascending: ascending),
          originName: (t) => t.accountId ?? '',
          categoryName: (t) => t.categoryId ?? '',
        ).map((t) => t.id).toList();

    test('kDefaultTxSort coincide com visibleTransactions', () {
      final sorted = sortTransactions(
        rows,
        kDefaultTxSort,
        originName: (t) => '',
        categoryName: (t) => '',
      ).map((t) => t.id);
      final visible = visibleTransactions(
        rows,
        nov,
        const TransactionFilter(),
      ).map((t) => t.id);
      expect(sorted, visible);
    });

    test('cada coluna em asc e desc', () {
      expect(ids(TxSortColumn.date, ascending: true), ['c', 'a', 'b']);
      expect(ids(TxSortColumn.date, ascending: false), ['b', 'a', 'c']);
      expect(ids(TxSortColumn.description, ascending: true), ['b', 'a', 'c']);
      expect(ids(TxSortColumn.description, ascending: false), ['c', 'a', 'b']);
      expect(ids(TxSortColumn.origin, ascending: true), ['b', 'a', 'c']);
      expect(ids(TxSortColumn.origin, ascending: false), ['c', 'a', 'b']);
      expect(ids(TxSortColumn.category, ascending: true), ['c', 'b', 'a']);
      expect(ids(TxSortColumn.category, ascending: false), ['a', 'b', 'c']);
      expect(ids(TxSortColumn.value, ascending: true), ['b', 'c', 'a']);
      expect(ids(TxSortColumn.value, ascending: false), ['a', 'c', 'b']);
    });

    test(
      'empate de valor resolvido por data desc; empate total por id asc',
      () {
        final tied = [
          _tx('x', cents: 500, date: DateTime(2026, 11, 5)),
          _tx('y', cents: 500, date: DateTime(2026, 11, 9)),
          _tx('z', cents: 100, date: DateTime(2026, 11, 1)),
          _tx('w', cents: 900, date: DateTime(2026, 11, 1)),
          _tx('v', cents: 900, date: DateTime(2026, 11, 1)),
        ];
        final sorted = sortTransactions(
          tied,
          (column: TxSortColumn.value, ascending: true),
          originName: (t) => '',
          categoryName: (t) => '',
        ).map((t) => t.id).toList();
        expect(sorted, ['z', 'y', 'x', 'v', 'w']);
      },
    );

    test('não altera a lista de entrada', () {
      final before = rows.map((t) => t.id).toList();
      sortTransactions(
        rows,
        (column: TxSortColumn.value, ascending: true),
        originName: (t) => '',
        categoryName: (t) => '',
      );
      expect(rows.map((t) => t.id).toList(), before);
    });

    test('toggleTxSort alterna ou troca de coluna', () {
      expect(toggleTxSort(kDefaultTxSort, TxSortColumn.date), (
        column: TxSortColumn.date,
        ascending: true,
      ));
      expect(toggleTxSort(kDefaultTxSort, TxSortColumn.description), (
        column: TxSortColumn.description,
        ascending: true,
      ));
      expect(toggleTxSort(kDefaultTxSort, TxSortColumn.value), (
        column: TxSortColumn.value,
        ascending: false,
      ));
      expect(
        toggleTxSort((
          column: TxSortColumn.value,
          ascending: false,
        ), TxSortColumn.value),
        (column: TxSortColumn.value, ascending: true),
      );
    });
  });

  test('hasCriteria só com algum filtro ativo', () {
    expect(const TransactionFilter().hasCriteria, isFalse);
    expect(const TransactionFilter(query: '  ').hasCriteria, isFalse);
    expect(const TransactionFilter(categoryId: 'x').hasCriteria, isTrue);
    expect(const TransactionFilter(showPlanned: false).hasCriteria, isTrue);
  });
}
