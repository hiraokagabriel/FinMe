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
}
