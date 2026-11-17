import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:finme/features/net_worth/presentation/net_worth_chart.dart';
import 'package:finme/features/net_worth/presentation/net_worth_page.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hoje é 15/11/2026. Dados de SPEC §5.26 (nov: líquido 4670000; out: 4920000).
Future<AppServices> _setup(
  WidgetTester tester, {
  bool ultra = false,
  bool hideValues = false,
  List<Debt>? debts,
  bool withSpecData = true,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    if (withSpecData) {
      await s.accounts.upsertAll(_accounts);
      await s.cards.upsertAll([_cardK]);
      await s.transactions.upsertAll(_transactions);
      await s.assets.upsertAll([_carro, _tesouro]);
      await s.debts.upsertAll(debts ?? _debts);
    } else {
      await s.debts.upsertAll(debts ?? const []);
    }
    await s.settings.update(
      (x) => x.copyWith(
        mode: ultra ? AppMode.ultra : AppMode.simple,
        hideValues: hideValues,
      ),
    );
    return s;
  }))!;
}

Future<void> _pump(WidgetTester tester, AppServices s) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: NetWorthPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _accounts = [
  Account(
    id: 'a',
    name: 'Conta A',
    bankName: 'Banco A',
    type: AccountType.checking,
    initialBalanceCents: 100000,
    colorValue: 0xFF42A5F5,
  ),
  Account(
    id: 'inv',
    name: 'Inv',
    bankName: 'Banco A',
    type: AccountType.investment,
    initialBalanceCents: 500000,
    colorValue: 0xFF42A5F5,
  ),
  Account(
    id: 'x',
    name: 'Antiga',
    bankName: 'Banco A',
    type: AccountType.checking,
    initialBalanceCents: 999999,
    colorValue: 0xFF42A5F5,
    archived: true,
  ),
];

final _cardK = const PaymentCard(
  id: 'k',
  name: 'Cartão K',
  bankName: 'Banco A',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '1234',
  closingDay: 28,
  dueDay: 5,
  colorValue: 0xFF1565C0,
  paymentAccountId: 'a',
);

Transaction _tx(
  String id,
  TransactionType type,
  int cents,
  DateTime date, {
  String? account,
  String? card,
  TransactionStatus status = TransactionStatus.paid,
  String? group,
  int? index,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date,
  description: id,
  accountId: account,
  cardId: card,
  status: status,
  installmentGroupId: group,
  installmentIndex: index,
  installmentCount: index == null ? null : 3,
);

final _transactions = [
  _tx(
    'r1',
    TransactionType.income,
    300000,
    DateTime(2026, 10, 5),
    account: 'a',
  ),
  _tx(
    'd1',
    TransactionType.expense,
    50000,
    DateTime(2026, 11, 10),
    account: 'a',
  ),
  _tx(
    'p70',
    TransactionType.expense,
    70000,
    DateTime(2026, 11, 20),
    account: 'a',
    status: TransactionStatus.planned,
  ),
  _tx(
    'r2',
    TransactionType.income,
    20000,
    DateTime(2026, 11, 10),
    account: 'a',
  ),
  _tx('c0', TransactionType.expense, 30000, DateTime(2026, 9, 5), card: 'k'),
  _tx(
    'i1',
    TransactionType.expense,
    40000,
    DateTime(2026, 10, 15),
    card: 'k',
    group: 'g',
    index: 1,
  ),
  _tx(
    'i2',
    TransactionType.expense,
    40000,
    DateTime(2026, 11, 15),
    card: 'k',
    group: 'g',
    index: 2,
  ),
  _tx(
    'i3',
    TransactionType.expense,
    40000,
    DateTime(2026, 12, 15),
    card: 'k',
    group: 'g',
    index: 3,
  ),
  _tx(
    'pay',
    TransactionType.invoicePayment,
    30000,
    DateTime(2026, 10, 5),
    account: 'a',
    card: 'k',
  ),
];

final _carro = Asset(
  id: 'carro',
  name: 'Carro',
  kind: AssetKind.vehicle,
  snapshots: [
    AssetSnapshot(id: 's1', date: DateTime(2026, 8, 1), valueCents: 4000000),
    AssetSnapshot(id: 's2', date: DateTime(2026, 11, 1), valueCents: 3800000),
  ],
);

final _tesouro = Asset(
  id: 'tesouro',
  name: 'Tesouro',
  kind: AssetKind.investment,
  snapshots: [
    AssetSnapshot(id: 's3', date: DateTime(2026, 10, 10), valueCents: 200000),
  ],
);

final _debts = [
  Debt(
    id: 'd1',
    person: 'Ana',
    direction: DebtDirection.owedToMe,
    amountCents: 50000,
    date: DateTime(2026, 10, 1),
    payments: [
      DebtPayment(
        id: 'p1',
        date: DateTime(2026, 11, 10),
        amountCents: 20000,
        transactionId: 'r2',
      ),
    ],
  ),
  Debt(
    id: 'd2',
    person: 'Bruno',
    direction: DebtDirection.iOwe,
    amountCents: 80000,
    date: DateTime(2026, 9, 20),
  ),
];

Finder _inKpi(String text) => find.descendant(
  of: find.byKey(const Key('net-worth-kpi')),
  matching: find.text(text),
);

void main() {
  testWidgets('Simples: KPI 46.700 com linha de apoio e sem Evolução', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(tester, s);

    expect(_inKpi('R\$ 46.700,00'), findsOneWidget);
    expect(find.text('Contas '), findsOneWidget);
    expect(find.text(' · Dívidas '), findsOneWidget);
    expect(find.text('Evolução'), findsNothing);
    expect(find.text('Composição'), findsNothing);
    expect(find.byType(DeltaBadge), findsNothing);
  });

  testWidgets('Ultra: variação -2.500 com DeltaBadge e gráfico de 12 pontos', (
    tester,
  ) async {
    final s = await _setup(tester, ultra: true);
    await _pump(tester, s);

    expect(_inKpi('R\$ 46.700,00'), findsOneWidget);
    expect(find.byType(DeltaBadge), findsOneWidget);
    expect(find.textContaining('2.500,00'), findsWidgets);
    expect(
      tester.widget<NetWorthChart>(find.byType(NetWorthChart)).points.length,
      12,
    );
  });

  testWidgets('Ultra: seletor 24 meses mostra 24 pontos', (tester) async {
    final s = await _setup(tester, ultra: true);
    await _pump(tester, s);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('net-worth-range')),
        matching: find.text('24 meses'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<NetWorthChart>(find.byType(NetWorthChart)).points.length,
      24,
    );
  });

  testWidgets('Ultra: composição mostra dívida de cartão de R\$ 1.200,00', (
    tester,
  ) async {
    final s = await _setup(tester, ultra: true);
    await _pump(tester, s);

    final breakdown = find.byKey(const Key('net-worth-breakdown'));
    expect(
      find.descendant(of: breakdown, matching: find.text('R\$ 1.200,00')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: breakdown,
        matching: find.text('Faturas em aberto e parcelas futuras já lançadas'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('botões do cabeçalho abrem os diálogos de dívida e ativo', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(tester, s);

    await tester.tap(
      find.descendant(
        of: find.byType(PageHeader),
        matching: find.text('Nova dívida'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nova dívida'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(PageHeader),
        matching: find.text('Novo ativo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('patrimônio negativo: KPI em danger', (tester) async {
    final s = await _setup(
      tester,
      withSpecData: false,
      debts: [
        Debt(
          id: 'dv',
          person: 'Carla',
          direction: DebtDirection.iOwe,
          amountCents: 10000,
          date: DateTime(2026, 10, 1),
        ),
      ],
    );
    await _pump(tester, s);

    final text = tester.widget<Text>(_inKpi('-R\$ 100,00'));
    final danger = AppTheme.light().extension<AppColors>()!.danger;
    expect(text.style?.color, danger);
  });

  testWidgets('hideValues: nenhum valor em claro na página', (tester) async {
    final s = await _setup(tester, ultra: true, hideValues: true);
    await _pump(tester, s);

    expect(find.textContaining('46.700'), findsNothing);
    expect(find.textContaining('1.200'), findsNothing);
    expect(find.textContaining('••••'), findsWidgets);
  });
}
