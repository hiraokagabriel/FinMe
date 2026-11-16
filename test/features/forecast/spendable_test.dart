import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/forecast/domain/spendable.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final _hoje = DateTime(2026, 11, 15);

Account _conta(
  String id, {
  int initial = 0,
  AccountType type = AccountType.checking,
  bool archived = false,
}) => Account(
  id: id,
  name: id,
  bankName: 'Banco Teste',
  type: type,
  initialBalanceCents: initial,
  colorValue: 0xFF1565C0,
  archived: archived,
);

PaymentCard _cartao(
  String id, {
  required int closingDay,
  required int dueDay,
  String paymentAccountId = 'A',
}) => PaymentCard(
  id: id,
  name: id,
  bankName: 'Banco Teste',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '0000',
  closingDay: closingDay,
  dueDay: dueDay,
  colorValue: 0xFF1565C0,
  paymentAccountId: paymentAccountId,
);

Transaction _tx(
  String id, {
  required TransactionType type,
  required int amount,
  required DateTime date,
  String? accountId,
  String? cardId,
  String? toAccountId,
  TransactionStatus status = TransactionStatus.paid,
  bool isBoleto = false,
  String? invoiceKey,
}) => Transaction(
  id: id,
  type: type,
  amountCents: amount,
  date: date,
  description: id,
  accountId: accountId,
  cardId: cardId,
  toAccountId: toAccountId,
  status: status,
  isBoleto: isBoleto,
  invoiceKey: invoiceKey,
);

RecurringRule _regra(
  String id, {
  required TransactionType type,
  required int amount,
  required int dia,
  String? accountId = 'A',
  String? cardId,
  bool active = true,
}) => RecurringRule(
  id: id,
  description: id,
  type: type,
  amountCents: amount,
  frequency: Frequency.monthly,
  startDate: DateTime(2026, 1, dia),
  accountId: accountId,
  cardId: cardId,
  active: active,
);

/// Cenário de §5.23: A 300000, B 50000, C arquivada 999999; K1 (vence 05/12, 80000) e K2 (vence 10/12, 120000) pagas por A.
List<Account> _contasExemplo() => [
  _conta('A', initial: 300000),
  _conta('B', initial: 50000),
  _conta('C', initial: 999999, archived: true),
];

List<PaymentCard> _cartoesExemplo() => [
  _cartao('K1', closingDay: 28, dueDay: 5),
  _cartao('K2', closingDay: 3, dueDay: 10),
];

List<Transaction> _txExemplo() => [
  _tx(
    'k1',
    type: TransactionType.expense,
    amount: 80000,
    date: DateTime(2026, 11, 10),
    cardId: 'K1',
  ),
  _tx(
    'k2',
    type: TransactionType.expense,
    amount: 120000,
    date: DateTime(2026, 11, 5),
    cardId: 'K2',
  ),
  _tx(
    'boleto',
    type: TransactionType.expense,
    amount: 25000,
    date: DateTime(2026, 11, 20),
    accountId: 'A',
    status: TransactionStatus.planned,
    isBoleto: true,
  ),
  _tx(
    'atrasada',
    type: TransactionType.expense,
    amount: 5000,
    date: DateTime(2026, 11, 10),
    accountId: 'B',
    status: TransactionStatus.planned,
  ),
  _tx(
    'transf',
    type: TransactionType.transfer,
    amount: 10000,
    date: DateTime(2026, 11, 18),
    accountId: 'A',
    toAccountId: 'B',
    status: TransactionStatus.planned,
  ),
];

RecurringRule _salario() =>
    _regra('Salário', type: TransactionType.income, amount: 500000, dia: 5);

RecurringRule _aluguel() =>
    _regra('Aluguel', type: TransactionType.expense, amount: 150000, dia: 1);

/// Monta a previsão e chama `spendableToday` com os dados do cenário; padrões = exemplo completo.
SpendableToday _spend({
  DateTime? hoje,
  List<Account>? contas,
  List<PaymentCard>? cartoes,
  List<Transaction>? txs,
  List<RecurringRule>? regras,
  Map<String, int>? reservas,
}) {
  final today = hoje ?? _hoje;
  final accounts = contas ?? _contasExemplo();
  final rules = regras ?? [_salario(), _aluguel()];
  final forecast = ForecastService.compute(
    accounts: accounts,
    cards: cartoes ?? _cartoesExemplo(),
    transactions: txs ?? _txExemplo(),
    recurring: rules,
    today: today,
    months: 6,
    minDays: 60,
  );
  return spendableToday(
    forecast: forecast,
    recurring: rules,
    accountsById: {for (final a in accounts) a.id: a},
    reservedByAccount: reservas ?? {'A': 40000},
    horizonEnd: ForecastService.horizonEnd(
      today: today,
      months: 6,
      minDays: 60,
    ),
  );
}

void main() {
  test('exemplo completo de §5.23', () {
    final s = _spend();
    expect(s.nextIncomeDate, DateTime(2026, 12, 5));
    expect(s.nextIncomeDescription, 'Salário');
    expect(s.untilDate, DateTime(2026, 12, 5));
    expect(s.days, 20);
    expect(s.balanceCents, 350000);
    expect(s.invoicesCents, 80000);
    expect(s.invoiceEvents, hasLength(1));
    expect(s.plannedCents, 180000);
    expect(s.plannedEvents, hasLength(3));
    expect(s.plannedEvents.first.date, DateTime(2026, 11, 15));
    expect(s.reservedCents, 40000);
    expect(s.freeCents, 50000);
    expect(s.perDayCents, 2500);
    expect(s.overcommitted, isFalse);
  });

  test('sem salário: até o fim do mês', () {
    final s = _spend(regras: [_aluguel()]);
    expect(s.nextIncomeDate, isNull);
    expect(s.untilDate, DateTime(2026, 11, 30));
    expect(s.days, 16);
    expect(s.invoicesCents, 0);
    expect(s.plannedCents, 30000);
    expect(s.freeCents, 280000);
    expect(s.perDayCents, 17500);
  });

  test('reserva de 400000 é limitada ao saldo e deixa o dia sem folga', () {
    final s = _spend(reservas: {'A': 400000});
    expect(s.reservedCents, 300000);
    expect(s.freeCents, -210000);
    expect(s.overcommitted, isTrue);
    expect(s.perDayCents, 0);
  });

  test('hoje 30/11 sem salário: 1 dia de gasto', () {
    final s = _spend(hoje: DateTime(2026, 11, 30), regras: [_aluguel()]);
    expect(s.days, 1);
  });

  test('hoje 04/12 com salário no dia 5: 1 dia de gasto', () {
    final s = _spend(hoje: DateTime(2026, 12, 4));
    expect(s.nextIncomeDate, DateTime(2026, 12, 5));
    expect(s.days, 1);
  });

  test('hoje 05/12 com salário no dia 5: próxima é 05/01/2027', () {
    final s = _spend(hoje: DateTime(2026, 12, 5));
    expect(s.nextIncomeDate, DateTime(2027, 1, 5));
  });

  test(
    'receita inativa, em cartão, sem conta ou em conta arquivada não define a data',
    () {
      final s = _spend(
        regras: [
          _regra(
            'Inativa',
            type: TransactionType.income,
            amount: 1000,
            dia: 20,
            active: false,
          ),
          _regra(
            'Cartão',
            type: TransactionType.income,
            amount: 1000,
            dia: 20,
            accountId: null,
            cardId: 'K1',
          ),
          _regra(
            'Sem conta',
            type: TransactionType.income,
            amount: 1000,
            dia: 20,
            accountId: null,
          ),
          _regra(
            'Arquivada',
            type: TransactionType.income,
            amount: 1000,
            dia: 20,
            accountId: 'C',
          ),
        ],
      );
      expect(s.nextIncomeDate, isNull);
      expect(s.untilDate, DateTime(2026, 11, 30));
      expect(s.days, 16);
    },
  );

  test('duas receitas: a mais próxima vence', () {
    final s = _spend(
      regras: [
        _regra('Salário', type: TransactionType.income, amount: 500000, dia: 5),
        _regra('Freela', type: TransactionType.income, amount: 90000, dia: 20),
      ],
    );
    expect(s.nextIncomeDate, DateTime(2026, 11, 20));
    expect(s.nextIncomeDescription, 'Freela');
    expect(s.days, 5);
  });

  test('empate de data: a 1ª regra na ordem de entrada vence', () {
    final s = _spend(
      regras: [
        _regra('X', type: TransactionType.income, amount: 1000, dia: 20),
        _regra('Y', type: TransactionType.income, amount: 1000, dia: 20),
      ],
    );
    expect(s.nextIncomeDescription, 'X');
  });

  test('fatura vencida entra em hoje; fatura quitada não entra', () {
    final cartao = _cartao('K3', closingDay: 3, dueDay: 10);
    final vencida = _spend(
      regras: [_aluguel()],
      cartoes: [cartao],
      txs: [
        _tx(
          'compra',
          type: TransactionType.expense,
          amount: 30000,
          date: DateTime(2026, 10, 5),
          cardId: 'K3',
        ),
      ],
    );
    expect(vencida.invoiceEvents, hasLength(1));
    expect(vencida.invoiceEvents.single.date, _hoje);
    expect(vencida.invoicesCents, 30000);

    final quitada = _spend(
      regras: [_aluguel()],
      cartoes: [cartao],
      txs: [
        _tx(
          'compra',
          type: TransactionType.expense,
          amount: 30000,
          date: DateTime(2026, 10, 5),
          cardId: 'K3',
        ),
        _tx(
          'pagamento',
          type: TransactionType.invoicePayment,
          amount: 30000,
          date: DateTime(2026, 11, 12),
          accountId: 'A',
          cardId: 'K3',
          invoiceKey: '2026-11',
        ),
      ],
    );
    expect(quitada.invoiceEvents, isEmpty);
    expect(quitada.invoicesCents, 0);
  });

  test('1 centavo livre com 20 dias arredonda por dia para 0', () {
    final s = _spend(reservas: {'A': 89999});
    expect(s.freeCents, 1);
    expect(s.days, 20);
    expect(s.perDayCents, 0);
  });

  test(
    'conta de investimento fica fora do saldo e das reservas, mas paga provisionados',
    () {
      final contas = [
        ..._contasExemplo(),
        _conta('I', initial: 500000, type: AccountType.investment),
      ];
      final txs = [
        ..._txExemplo(),
        _tx(
          'invest',
          type: TransactionType.expense,
          amount: 7000,
          date: DateTime(2026, 11, 25),
          accountId: 'I',
          status: TransactionStatus.planned,
        ),
      ];
      final s = _spend(
        contas: contas,
        txs: txs,
        reservas: {'A': 40000, 'I': 100000},
      );
      expect(s.balanceCents, 350000);
      expect(s.reservedCents, 40000);
      expect(s.plannedCents, 187000);
      expect(s.freeCents, 43000);
    },
  );

  test(
    'transferência de conta elegível para investimento, arquivada ou inexistente é provisionado; entre elegíveis e vinda do investimento não',
    () {
      final contas = [
        ..._contasExemplo(),
        _conta('I', initial: 500000, type: AccountType.investment),
      ];
      final txs = [
        ..._txExemplo(), // A→B (elegíveis): fora
        _tx(
          'para_invest',
          type: TransactionType.transfer,
          amount: 7000,
          date: DateTime(2026, 11, 18),
          accountId: 'A',
          toAccountId: 'I',
          status: TransactionStatus.planned,
        ),
        _tx(
          'para_arquivada',
          type: TransactionType.transfer,
          amount: 3000,
          date: DateTime(2026, 11, 18),
          accountId: 'A',
          toAccountId: 'C',
          status: TransactionStatus.planned,
        ),
        _tx(
          'para_inexistente',
          type: TransactionType.transfer,
          amount: 1000,
          date: DateTime(2026, 11, 18),
          accountId: 'A',
          toAccountId: 'Z',
          status: TransactionStatus.planned,
        ),
        _tx(
          'do_invest',
          type: TransactionType.transfer,
          amount: 9000,
          date: DateTime(2026, 11, 18),
          accountId: 'I',
          toAccountId: 'A',
          status: TransactionStatus.planned,
        ),
      ];
      final s = _spend(contas: contas, txs: txs);
      expect(s.plannedCents, 180000 + 7000 + 3000 + 1000);
      expect(
        s.plannedEvents
            .where((e) => e.kind == ForecastEventKind.transfer)
            .map((e) => e.sourceId),
        unorderedEquals(['para_invest', 'para_arquivada', 'para_inexistente']),
      );
      expect(s.balanceCents, 350000);
    },
  );

  test('reserva negativa (dado corrompido) não soma', () {
    final s = _spend(reservas: {'A': -5000});
    expect(s.reservedCents, 0);
  });
}
