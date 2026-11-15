import '../core/models/year_month.dart';
import '../core/theme/app_palettes.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/id.dart';
import '../features/accounts/domain/account.dart';
import '../features/cards/domain/invoice.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/categories/domain/transaction_category.dart';
import '../features/recurring/domain/recurring_rule.dart';
import '../features/transactions/domain/installments.dart';
import '../features/transactions/domain/transaction.dart';
import 'app_scope.dart';

/// Categorias padrão: 12 de despesa e 4 de receita. Ids fixos `cat_<slug>`.
List<TransactionCategory> defaultCategories() {
  TransactionCategory cat(
    String slug,
    String name,
    CategoryKind kind,
    int icon,
    int color,
  ) => TransactionCategory(
    id: 'cat_$slug',
    name: name,
    kind: kind,
    iconCodePoint: kCategoryIcons[icon],
    colorValue: kEntityColors[color],
  );
  const e = CategoryKind.expense;
  const r = CategoryKind.income;
  return [
    cat('alimentacao', 'Alimentação', e, 0, 2),
    cat('mercado', 'Mercado', e, 1, 1),
    cat('transporte', 'Transporte', e, 2, 0),
    cat('moradia', 'Moradia', e, 3, 3),
    cat('saude', 'Saúde', e, 4, 4),
    cat('educacao', 'Educação', e, 5, 6),
    cat('lazer', 'Lazer', e, 6, 7),
    cat('assinaturas', 'Assinaturas', e, 22, 8),
    cat('compras', 'Compras', e, 16, 9),
    cat('contas_servicos', 'Contas e serviços', e, 13, 5),
    cat('viagem', 'Viagem', e, 7, 3),
    cat('outros', 'Outros', e, 28, 9),
    cat('salario', 'Salário', r, 19, 1),
    cat('freelance', 'Freelance', r, 20, 0),
    cat('rendimentos', 'Rendimentos', r, 21, 5),
    cat('outras_receitas', 'Outras receitas', r, 17, 7),
  ];
}

const _alfa = 'acc_alfa';
const _beta = 'acc_beta';
const _cash = 'acc_cash';
const _alfaVisa = 'card_alfa_visa';
const _betaMaster = 'card_beta_master';
const _gamaElo = 'card_gama_elo';
const _alfaDebit = 'card_alfa_debito';

/// Dados fictícios relativos a `clock()`. Não é ponto de partida para contas reais.
/// Materializa as recorrências só depois (`materializeRecurring`).
Future<void> seedDemo(AppServices s) async {
  final now = dateOnly(s.clock());
  final card = {
    _alfaVisa: PaymentCard(
      id: _alfaVisa,
      name: 'Alfa Visa',
      bankName: 'Banco Alfa',
      brand: CardBrand.visa,
      kind: CardKind.credit,
      last4: '1234',
      limitCents: 800000,
      closingDay: 5,
      dueDay: 12,
      paymentAccountId: _alfa,
      colorValue: kEntityColors[3],
    ),
    _betaMaster: PaymentCard(
      id: _betaMaster,
      name: 'Beta Master',
      bankName: 'Banco Beta',
      brand: CardBrand.mastercard,
      kind: CardKind.credit,
      last4: '5678',
      limitCents: 500000,
      closingDay: 25,
      dueDay: 5,
      paymentAccountId: _beta,
      colorValue: kEntityColors[4],
    ),
    _gamaElo: PaymentCard(
      id: _gamaElo,
      name: 'Gama Elo',
      bankName: 'Cooperativa Gama',
      brand: CardBrand.elo,
      kind: CardKind.credit,
      last4: '9012',
      limitCents: 300000,
      closingDay: 20,
      dueDay: 27,
      paymentAccountId: _beta,
      colorValue: kEntityColors[5],
    ),
    _alfaDebit: PaymentCard(
      id: _alfaDebit,
      name: 'Alfa Débito',
      bankName: 'Banco Alfa',
      brand: CardBrand.visa,
      kind: CardKind.debit,
      last4: '3456',
      closingDay: 1,
      dueDay: 1,
      paymentAccountId: _alfa,
      colorValue: kEntityColors[6],
    ),
  };

  await s.accounts.upsertAll([
    Account(
      id: _alfa,
      name: 'Conta corrente',
      bankName: 'Banco Alfa',
      type: AccountType.checking,
      initialBalanceCents: 850000,
      colorValue: kEntityColors[0],
    ),
    Account(
      id: _beta,
      name: 'Conta corrente',
      bankName: 'Banco Beta',
      type: AccountType.checking,
      initialBalanceCents: 320000,
      colorValue: kEntityColors[1],
    ),
    Account(
      id: _cash,
      name: 'Carteira',
      bankName: '',
      type: AccountType.cash,
      initialBalanceCents: 15000,
      colorValue: kEntityColors[2],
    ),
  ]);
  await s.cards.upsertAll(card.values);

  final txs = _demoTransactions(now);
  final previous = YearMonth.fromDate(now).prev();
  final previousInvoice = InvoiceService.build(
    card: card[_alfaVisa]!,
    transactions: txs,
  ).where((i) => i.dueMonth == previous).firstOrNull;
  if (previousInvoice != null && previousInvoice.totalCents > 0) {
    txs.add(
      Transaction(
        id: newId(),
        type: TransactionType.invoicePayment,
        amountCents: previousInvoice.totalCents,
        date: previousInvoice.dueDate,
        description: 'Pagamento da fatura Alfa Visa',
        accountId: _alfa,
        cardId: _alfaVisa,
        invoiceKey: previous.key,
      ),
    );
  }
  await s.transactions.upsertAll(txs);

  final start = YearMonth.fromDate(now).addMonths(-3);
  await s.recurring.upsertAll([
    RecurringRule(
      id: 'rec_salario',
      description: 'Salário',
      type: TransactionType.income,
      amountCents: 650000,
      frequency: Frequency.monthly,
      startDate: start.dateAt(5),
      accountId: _alfa,
      categoryId: 'cat_salario',
    ),
    RecurringRule(
      id: 'rec_aluguel',
      description: 'Aluguel',
      type: TransactionType.expense,
      amountCents: 180000,
      frequency: Frequency.monthly,
      startDate: start.dateAt(10),
      accountId: _beta,
      categoryId: 'cat_moradia',
      isBoleto: true,
    ),
    RecurringRule(
      id: 'rec_streaming',
      description: 'Streaming de vídeo',
      type: TransactionType.expense,
      amountCents: 3990,
      frequency: Frequency.monthly,
      startDate: start.dateAt(15),
      cardId: _alfaVisa,
      categoryId: 'cat_assinaturas',
      isSubscription: true,
    ),
    RecurringRule(
      id: 'rec_academia',
      description: 'Academia',
      type: TransactionType.expense,
      amountCents: 11990,
      frequency: Frequency.monthly,
      startDate: start.dateAt(8),
      cardId: _betaMaster,
      categoryId: 'cat_assinaturas',
      isSubscription: true,
    ),
  ]);
}

/// Lançamentos dos últimos 3 meses (`daysAgo` negativo = futuro) e duas compras parceladas.
List<Transaction> _demoTransactions(DateTime now) {
  Transaction tx(
    TransactionType type,
    int cents,
    int daysAgo,
    String description, {
    String? category,
    String? account,
    String? card,
    String? to,
    bool boleto = false,
    TransactionStatus status = TransactionStatus.paid,
  }) => Transaction(
    id: newId(),
    type: type,
    amountCents: cents,
    date: DateTime(now.year, now.month, now.day - daysAgo),
    description: description,
    categoryId: category,
    accountId: account,
    cardId: card,
    toAccountId: to,
    isBoleto: boleto,
    status: status,
  );

  const e = TransactionType.expense;
  const inc = TransactionType.income;
  final list = <Transaction>[
    // Cartão Alfa Visa
    tx(
      e,
      38750,
      2,
      'Supermercado Central',
      category: 'cat_mercado',
      card: _alfaVisa,
    ),
    tx(
      e,
      9800,
      4,
      'Restaurante do centro',
      category: 'cat_alimentacao',
      card: _alfaVisa,
    ),
    tx(
      e,
      26000,
      6,
      'Posto Estrada',
      category: 'cat_transporte',
      card: _alfaVisa,
    ),
    tx(e, 8450, 9, 'Farmácia', category: 'cat_saude', card: _alfaVisa),
    tx(
      e,
      21990,
      15,
      'Loja de roupas',
      category: 'cat_compras',
      card: _alfaVisa,
    ),
    tx(e, 6400, 18, 'Cinema', category: 'cat_lazer', card: _alfaVisa),
    tx(
      e,
      41200,
      35,
      'Supermercado Central',
      category: 'cat_mercado',
      card: _alfaVisa,
    ),
    tx(
      e,
      12300,
      40,
      'Restaurante',
      category: 'cat_alimentacao',
      card: _alfaVisa,
    ),
    tx(e, 84000, 52, 'Passagem aérea', category: 'cat_viagem', card: _alfaVisa),
    tx(
      e,
      29990,
      66,
      'Mercado do bairro',
      category: 'cat_mercado',
      card: _alfaVisa,
    ),
    tx(e, 13500, 75, 'Livraria', category: 'cat_educacao', card: _alfaVisa),
    tx(e, 1890, 80, 'Cafeteria', category: 'cat_alimentacao', card: _alfaVisa),
    // Cartão Beta Master
    tx(e, 27800, 3, 'Mercado', category: 'cat_mercado', card: _betaMaster),
    tx(e, 1450, 7, 'Padaria', category: 'cat_alimentacao', card: _betaMaster),
    tx(
      e,
      49900,
      22,
      'Curso online',
      category: 'cat_educacao',
      card: _betaMaster,
    ),
    tx(e, 33100, 45, 'Mercado', category: 'cat_mercado', card: _betaMaster),
    tx(e, 15700, 60, 'Presente', category: 'cat_compras', card: _betaMaster),
    tx(
      e,
      2350,
      28,
      'Aplicativo de transporte',
      category: 'cat_transporte',
      card: _betaMaster,
    ),
    // Cartão Gama Elo
    tx(e, 19900, 11, 'Combustível', category: 'cat_transporte', card: _gamaElo),
    tx(e, 7600, 25, 'Restaurante', category: 'cat_alimentacao', card: _gamaElo),
    tx(
      e,
      58000,
      58,
      'Manutenção do carro',
      category: 'cat_transporte',
      card: _gamaElo,
    ),
    tx(e, 4300, 70, 'Farmácia', category: 'cat_saude', card: _gamaElo),
    // Débito (debitado da conta Alfa)
    tx(e, 2100, 1, 'Lanche', category: 'cat_alimentacao', card: _alfaDebit),
    tx(e, 18900, 8, 'Mercado', category: 'cat_mercado', card: _alfaDebit),
    tx(e, 15000, 30, 'Gasolina', category: 'cat_transporte', card: _alfaDebit),
    tx(
      e,
      9000,
      50,
      'Parque de diversões',
      category: 'cat_lazer',
      card: _alfaDebit,
    ),
    // Contas
    tx(
      e,
      8900,
      12,
      'Conta de água',
      category: 'cat_contas_servicos',
      account: _alfa,
    ),
    tx(
      e,
      21500,
      42,
      'Conta de energia',
      category: 'cat_contas_servicos',
      account: _alfa,
    ),
    tx(
      inc,
      120000,
      20,
      'Projeto freelance',
      category: 'cat_freelance',
      account: _alfa,
    ),
    tx(
      e,
      10990,
      33,
      'Internet',
      category: 'cat_contas_servicos',
      account: _alfa,
    ),
    tx(e, 8800, 55, 'Restaurante', category: 'cat_alimentacao', account: _alfa),
    tx(
      e,
      6990,
      16,
      'Telefone',
      category: 'cat_contas_servicos',
      account: _beta,
    ),
    tx(
      inc,
      4300,
      30,
      'Rendimento da poupança',
      category: 'cat_rendimentos',
      account: _beta,
    ),
    tx(
      inc,
      20000,
      45,
      'Presente recebido',
      category: 'cat_outras_receitas',
      account: _beta,
    ),
    // Carteira
    tx(e, 4500, 5, 'Feira', category: 'cat_mercado', account: _cash),
    tx(
      e,
      1200,
      13,
      'Estacionamento',
      category: 'cat_transporte',
      account: _cash,
    ),
    tx(e, 1800, 26, 'Lanche', category: 'cat_alimentacao', account: _cash),
    tx(e, 1000, 62, 'Gorjeta', category: 'cat_outros', account: _cash),
    // Transferência entre contas
    tx(
      TransactionType.transfer,
      50000,
      19,
      'Reserva de emergência',
      account: _alfa,
      to: _beta,
    ),
    // Boletos provisionados: um para daqui a 5 dias e um atrasado
    tx(
      e,
      45000,
      -5,
      'Boleto de energia',
      category: 'cat_contas_servicos',
      account: _alfa,
      boleto: true,
      status: TransactionStatus.planned,
    ),
    tx(
      e,
      27400,
      3,
      'Boleto de seguro',
      category: 'cat_outros',
      account: _beta,
      boleto: true,
      status: TransactionStatus.planned,
    ),
  ];
  list
    ..addAll(
      buildInstallments(
        base: tx(
          e,
          120000,
          60,
          'Notebook',
          category: 'cat_compras',
          card: _alfaVisa,
        ),
        count: 10,
        groupId: newId(),
      ),
    )
    ..addAll(
      buildInstallments(
        base: tx(
          e,
          90000,
          20,
          'Geladeira',
          category: 'cat_compras',
          card: _betaMaster,
        ),
        count: 3,
        groupId: newId(),
      ),
    );
  return list;
}
