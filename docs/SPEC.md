# FinMe v2 — Especificação

> Fonte da verdade de domínio e arquitetura. Coders seguem os contratos daqui à risca.
> Mudou o domínio? Atualize este arquivo primeiro (papel do `finme-planner`).

## 1. Produto

FinMe dá **previsibilidade** a quem gerencia muitos cartões de crédito, várias contas e muitas despesas.
Pergunta central: *"quanto vai sair, de onde e quando — e meu saldo aguenta?"*

Pilares:
1. **Faturas certas** por cartão (fechamento/vencimento, parcelas, assinaturas).
2. **Previsão de caixa** consolidada e por conta, com alerta de saldo negativo.
3. **Provisionamento**: boletos e despesas planejadas que ainda não saíram.
4. **Categorias e orçamento** mensal.
5. **Modo Simples** (enxuto) e **Modo Ultra** (denso) sobre o mesmo domínio.

Local, sem backend, sem integração bancária. Foco em funcionalidade e desempenho.

## 2. Arquitetura

```
lib/
  main.dart                    # runApp(bootstrap)
  app/
    app.dart                   # FinMeApp (MaterialApp, tema, home)
    bootstrap.dart             # abre storage, cria repos, seed, materializa recorrências
    app_scope.dart             # AppServices + AppScope (InheritedWidget)
    ledger.dart                # Ledger: visões derivadas memoizadas (faturas, saldos, previsão)
    home_shell.dart            # sidebar (desktop) / drawer (mobile) + troca de páginas
    seed.dart                  # categorias padrão + dados de exemplo fictícios
  core/
    models/                    # YearMonth, AppSettings, enums globais
    services/                  # RecordStore, CollectionRepository, SettingsController
    theme/                     # AppColors (ThemeExtension), AppTheme, AppSpace, AppRadius, paletas
    utils/                     # formatters, date_utils, id
    widgets/                   # widgets compartilhados (MoneyText, SectionCard, ...)
  features/
    accounts/{domain,presentation}
    cards/{domain,presentation}
    categories/{domain,presentation}
    transactions/{domain,presentation}
    recurring/{domain,presentation}
    forecast/{domain,presentation}
    dashboard/presentation
    settings/presentation
    onboarding/presentation
```

Regras:
- `domain/` e `core/models|utils` = **Dart puro** (sem `package:flutter`). Testado com `flutter test`.
- Persistência genérica: cada entidade tem `toMap()`/`fromMap()`; não há adapters Hive nem typeIds.
- Estado: `ChangeNotifier` + `ListenableBuilder`. Sem pacotes de estado.
- Todos os dados ficam **em memória** (carregados no boot); escrita no Hive é assíncrona.
- Derivados caros (faturas, saldos, previsão) são calculados no `Ledger` e memoizados por versão dos repositórios — nunca em `build`.
- Navegação: índice no `HomeShell`; formulários em `showDialog` (largura máx. 520).
- Dependências permitidas: `hive`, `hive_flutter`, `path_provider`, `fl_chart`, `csv`, `file_selector`. Nenhuma outra.

## 3. Core

### 3.1 `lib/core/models/year_month.dart`
```dart
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month); // month 1..12
  factory YearMonth.fromDate(DateTime d);
  factory YearMonth.fromKey(String key);   // "2026-11"
  final int year, month;
  String get key;                          // "2026-11" (mês com 2 dígitos)
  int get daysInMonth;
  DateTime get firstDay;                   // DateTime(year, month, 1)
  DateTime get lastDay;
  YearMonth addMonths(int n);              // aceita negativo, cruza anos
  YearMonth next(); YearMonth prev();
  DateTime dateAt(int day);                // dia limitado a 1..daysInMonth
  bool contains(DateTime d);
  int compareTo(YearMonth o);
  // == e hashCode por (year, month); operadores <, <=, >, >=
}
```

### 3.2 `lib/core/utils/date_utils.dart`
- `DateTime dateOnly(DateTime d)` → meia-noite local.
- `DateTime addMonthsClamped(DateTime d, int months)` → mesmo dia limitado ao fim do mês (31/01 + 1 = 28/02 ou 29/02).
- `bool isSameDay(DateTime a, DateTime b)`.
- `String dateKey(DateTime d)` → `"20261114"`.

### 3.3 `lib/core/utils/formatters.dart`
- `String formatMoney(int cents, {bool hidden = false, bool signed = false})` → `"R$ 1.234,56"`, negativo `"-R$ 1.234,56"`, `signed` prefixa `+` em positivos, `hidden` → `"R$ ••••"`.
- `int? parseMoney(String input)` → aceita `"1.234,56"`, `"1234,5"`, `"1234.56"`, `"R$ 10"`, `"-5,00"`; inválido → `null`.
- `String formatDate(DateTime d)` `"14/11/2026"`; `String formatShortDate(DateTime d)` `"14/11"`.
- `String formatMonth(YearMonth m)` `"nov/2026"`; `String formatMonthLong(YearMonth m)` `"Novembro 2026"`.

### 3.4 `lib/core/utils/id.dart`
- `String newId()` → único por processo (timestamp em micros base36 + contador + random). Sem dependência.

### 3.5 Persistência — `lib/core/services/`
```dart
// record_store.dart
abstract interface class RecordStore {
  Iterable<Map<String, dynamic>> loadAll();
  Future<void> put(String id, Map<String, dynamic> data);
  Future<void> putAll(Map<String, Map<String, dynamic>> entries);
  Future<void> delete(String id);
  Future<void> deleteAll(Iterable<String> ids);
  Future<void> clear();
}
class MemoryRecordStore implements RecordStore { ... }      // testes
class HiveRecordStore implements RecordStore {             // Box<Map> do Hive
  HiveRecordStore(Box<Map> box);
  static Future<HiveRecordStore> open(String boxName);
}
// Mapas lidos do Hive são Map<dynamic,dynamic>: converter recursivamente para Map<String,dynamic>.

// collection_repository.dart
class CollectionRepository<T> extends ChangeNotifier {
  CollectionRepository({
    required RecordStore store,
    required T Function(Map<String, dynamic>) fromMap,
    required Map<String, dynamic> Function(T) toMap,
    required String Function(T) idOf,
  }); // carrega store.loadAll() no construtor
  List<T> get all;          // lista imutável cacheada, invalida ao mudar
  int get version;          // incrementa a cada mudança
  bool get isEmpty;
  T? byId(String id);
  Future<void> upsert(T item);
  Future<void> upsertAll(Iterable<T> items);   // um único notify
  Future<void> delete(String id);
  Future<void> deleteWhere(bool Function(T) test);
  Future<void> replaceAll(Iterable<T> items);  // import de backup
}
```
Boxes Hive (nomes novos, ignoram dados antigos): `fm_accounts`, `fm_cards`, `fm_categories`, `fm_transactions`, `fm_recurring`, `fm_settings`.

### 3.6 Configurações
```dart
// core/models/app_settings.dart
enum AppMode { simple, ultra }
enum ThemePreference { system, light, dark }
class AppSettings {
  final AppMode mode;              // padrão simple
  final ThemePreference theme;     // padrão system
  final bool hideValues;           // padrão false
  final int forecastMonths;        // padrão 6 (3..24)
  final bool onboardingDone;       // padrão false
  copyWith, toMap, fromMap (campos ausentes → padrão)
}
// core/services/settings_controller.dart
class SettingsController extends ChangeNotifier {
  SettingsController(RecordStore store); // registro único id "settings"
  AppSettings get value;
  Future<void> update(AppSettings Function(AppSettings) change);
}
```

## 4. Entidades de domínio

Todas imutáveis, com `copyWith`, `toMap`, `factory fromMap`. Enums serializados por `name`;
datas por `dateKey` (`"20261114"`); campos opcionais ausentes no mapa → `null`/padrão.
`fromMap` tolera enum desconhecido usando o primeiro valor.

### 4.1 `features/accounts/domain/account.dart`
```dart
enum AccountType { checking, savings, cash, investment, wallet }
class Account { id, name, bankName, type, int initialBalanceCents, int colorValue, bool archived }
```

### 4.2 `features/cards/domain/payment_card.dart`
```dart
enum CardBrand { visa, mastercard, elo, amex, hipercard, other }
enum CardKind { credit, debit }
class PaymentCard {
  id, name, bankName, brand, kind, String last4,
  int limitCents,          // crédito; 0 em débito
  int closingDay,          // 1..31 (crédito)
  int dueDay,              // 1..31 (crédito)
  String? paymentAccountId,// crédito: conta que paga a fatura; débito: conta debitada
  int colorValue, bool archived
}
```

### 4.3 `features/categories/domain/transaction_category.dart`
```dart
enum CategoryKind { expense, income }
class TransactionCategory { id, name, kind, int iconCodePoint, int colorValue, int? monthlyBudgetCents }
```

### 4.4 `features/transactions/domain/transaction.dart`
```dart
enum TransactionType { expense, income, transfer, invoicePayment }
enum TransactionStatus { paid, planned }
class Transaction {
  String id; TransactionType type;
  int amountCents;            // sempre > 0
  DateTime date;              // dateOnly
  String description;
  String? categoryId;
  String? accountId;          // origem (expense/income/transfer/invoicePayment)
  String? cardId;             // expense/income no cartão; invoicePayment: cartão pago
  String? toAccountId;        // transfer: destino
  TransactionStatus status;   // padrão paid
  bool isBoleto;              // padrão false
  String? invoiceKey;         // invoicePayment: YearMonth.key do vencimento da fatura
  String? installmentGroupId; int? installmentIndex; int? installmentCount; // 1-based
  String? recurringId;
  String? notes;
}
```
Regras:
- `expense`/`income`: exatamente um de `accountId` ou `cardId`.
- Lançamento em **cartão de crédito** compõe fatura; `status` é irrelevante (sempre tratado como lançado). `income` em cartão = estorno (abate a fatura).
- Lançamento em **cartão de débito** afeta a conta `card.paymentAccountId`.
- `transfer`: `accountId` → `toAccountId`; não é receita nem despesa.
- `invoicePayment`: sai de `accountId`, quita fatura (`cardId`, `invoiceKey`). Sempre `paid`.
- `planned` = provisionado: ainda não saiu. Não afeta saldo atual; entra na previsão.

### 4.5 `features/recurring/domain/recurring_rule.dart`
```dart
enum Frequency { weekly, monthly, yearly }
class RecurringRule {
  id, description, TransactionType type (expense|income), int amountCents,
  String? categoryId, String? accountId, String? cardId,
  Frequency frequency, DateTime startDate, DateTime? endDate,
  bool isSubscription, bool isBoleto, bool active
}
```

## 5. Regras financeiras (domínio puro)

### 5.1 Ciclo de fatura — `features/cards/domain/invoice_cycle.dart`
Convenção: compra **no dia do fechamento ou depois** vai para a próxima fatura.
```dart
YearMonth closingMonthFor(DateTime purchase, int closingDay);
  // closing = YearMonth.fromDate(purchase).dateAt(closingDay)
  // purchase.day < closing.day ? mês da compra : mês seguinte
YearMonth invoiceDueMonth(DateTime purchase, PaymentCard card);
  // c = closingMonthFor(...); card.dueDay > card.closingDay ? c : c.next()
DateTime invoiceClosingDate(YearMonth dueMonth, PaymentCard card);
  // (dueDay > closingDay ? dueMonth : dueMonth.prev()).dateAt(closingDay)
DateTime invoiceDueDate(YearMonth dueMonth, PaymentCard card); // dueMonth.dateAt(dueDay)
```
Exemplo: fecha 5, vence 12. Compra 04/11 → fatura vence 12/11. Compra 05/11 → vence 12/12.
Fecha 25, vence 5. Compra 24/11 → vence 05/12. Compra 25/11 → vence 05/01.

### 5.2 Fatura — `features/cards/domain/invoice.dart`
```dart
enum InvoiceStatus { open, closed, paid, overdue }
class Invoice {
  PaymentCard card; YearMonth dueMonth; DateTime closingDate; DateTime dueDate;
  List<Transaction> items;   // compras/estornos (inclui projetados), ordenados por data
  int chargesCents; int creditsCents; int paidCents;
  int get totalCents => chargesCents - creditsCents;
  int get remainingCents => max(0, totalCents - paidCents);
  String get id => '${card.id}_${dueMonth.key}';
  InvoiceStatus statusOn(DateTime today);
    // remaining == 0 → paid; today > dueDate → overdue; today >= closingDate → closed; senão open
}
class InvoiceService {
  static List<Invoice> build({
    required PaymentCard card,
    required Iterable<Transaction> transactions, // todas; filtra por cardId
    Iterable<Transaction> projected = const [],  // recorrências futuras do cartão
  }); // agrupa expense(+)/income(-) por invoiceDueMonth; invoicePayment soma em paidCents por invoiceKey; ordena por dueMonth
  static int usedLimitCents(Iterable<Invoice> invoices, DateTime today);
    // soma remainingCents das faturas com status != paid (inclui parcelas futuras)
  static Invoice? currentInvoice(Iterable<Invoice> invoices, DateTime today);
    // fatura não paga mais antiga (inclusive vencida); se todas pagas, null
}
```
Só cartões `credit` têm faturas.

### 5.3 Parcelas — `features/transactions/domain/installments.dart`
```dart
List<Transaction> buildInstallments({required Transaction base, required int count, required String groupId});
  // count >= 1. valor = base.amountCents ~/ count; resto somado à 1ª parcela.
  // parcela i (1..count): id '${groupId}_$i', date = addMonthsClamped(base.date, i-1),
  // installmentGroupId = groupId, installmentIndex = i, installmentCount = count.
  // soma das parcelas == base.amountCents (teste obrigatório)
```

### 5.4 Recorrência — `features/recurring/domain/recurrence.dart`
```dart
List<DateTime> occurrencesBetween(RecurringRule r, DateTime from, DateTime to);
  // inclusivo; respeita startDate/endDate; monthly: dia de startDate limitado ao mês
  // (31 → 28/29/30, sem "deslizar"); weekly: start + 7k; yearly: mesmo dia/mês limitado.
String occurrenceId(RecurringRule r, DateTime date); // '${r.id}_${dateKey(date)}'
List<Transaction> occurrenceTransactions(
  RecurringRule r, DateTime from, DateTime to, Set<String> existingIds,
  {required bool forProjection});
  // gera Transaction com id = occurrenceId, recurringId = r.id, copia campos.
  // pula ids em existingIds. r.active == false → [].
  // status: cardId != null → paid; accountId: forProjection ? planned : planned.
```
No boot (`bootstrap.dart`): materializa ocorrências de `startDate` até hoje (`forProjection: false`)
e grava. Ocorrências futuras **não** são gravadas: entram na previsão via projeção.

### 5.5 Saldos — `features/accounts/domain/balances.dart`
```dart
Map<String, int> accountBalances({
  required Iterable<Account> accounts,
  required Iterable<PaymentCard> cards,
  required Iterable<Transaction> transactions,
}); // initialBalance + efeitos de transações paid:
    // income(account) +, expense(account) -, expense/income em cartão de débito → conta do cartão,
    // transfer: origem -, destino +, invoicePayment: origem -.
    // cartão de crédito não afeta conta (só via invoicePayment).
int signedEffectOn(String accountId, Transaction t, Map<String, PaymentCard> cardsById);
```

### 5.6 Categorias — `features/categories/domain/category_spending.dart`
```dart
Map<String?, int> spendingByCategory(Iterable<Transaction> txs, YearMonth month, {bool includePlanned = false});
  // só expense; por data da compra (cartão incluso); chave null = sem categoria
class BudgetStatus { TransactionCategory category; int spentCents; int budgetCents; double get ratio; bool get exceeded; }
List<BudgetStatus> budgetStatuses(Iterable<TransactionCategory> cats, Map<String?, int> spending);
  // só categorias com monthlyBudgetCents != null && > 0, ordenadas por ratio desc
```

### 5.7 Previsão — `features/forecast/domain/forecast.dart`
```dart
enum ForecastEventKind { income, expense, boleto, invoice, transfer }
class ForecastEvent {
  DateTime date; int amountCents;  // com sinal (+ entra, - sai) do ponto de vista de accountId
  String description; String? accountId; String? toAccountId;
  ForecastEventKind kind; String sourceId; bool isProjected; // true = vindo de recorrência
}
class ForecastMonth { YearMonth month; int incomeCents; int expenseCents; int invoiceCents; int endBalanceCents; }
class DailyBalance { DateTime date; int balanceCents; }
class Forecast {
  DateTime today; Map<String, int> currentBalances; int currentTotalCents;
  List<ForecastEvent> events;          // ordenado por data
  List<ForecastMonth> months;          // mês atual + (months-1) seguintes
  List<DailyBalance> daily;            // um ponto por dia de today até o fim, saldo consolidado
  DateTime? firstNegativeDate;         // consolidado
  Map<String, DateTime> accountNegativeDates;
  int get lowestBalanceCents;
}
class ForecastService {
  static Forecast compute({
    required List<Account> accounts, required List<PaymentCard> cards,
    required List<Transaction> transactions, required List<RecurringRule> recurring,
    required DateTime today, int months = 6,
  });
}
```
Algoritmo:
1. `currentBalances` = `accountBalances(...)` (contas não arquivadas); `currentTotal` = soma.
2. Horizonte: `today` até `YearMonth.fromDate(today).addMonths(months - 1).lastDay`.
3. Eventos:
   - Transações `planned` de conta (income/expense/transfer, inclusive débito) com data ≤ fim. Atrasadas (data < today) entram **em today**. `isBoleto` → kind `boleto`.
   - Recorrências: `occurrenceTransactions(r, today, fim, idsExistentes, forProjection: true)`. De conta → evento (`isProjected: true`). De cartão de crédito → vão para `projected` da fatura.
   - Faturas: para cada cartão de crédito, `InvoiceService.build(card, transactions, projected)`; cada fatura com `remainingCents > 0` e `dueDate ≤ fim` gera evento `invoice` de `-remaining` em `max(dueDate, today)` na conta `card.paymentAccountId` (pode ser `null`: conta só no consolidado).
4. `transfer` não entra em income/expense mensal e tem efeito zero no consolidado.
5. `months[i]`: soma por mês de eventos; `endBalanceCents` = saldo consolidado no último dia do mês.
6. `daily`: saldo consolidado acumulado dia a dia; `firstNegativeDate` = primeiro dia < 0.
   `accountNegativeDates` análogo por conta.
Desempenho: O(n) sobre transações por cartão (agrupe por `cardId` uma vez).

## 6. Camada de app

### 6.1 `app/app_scope.dart`
```dart
class AppServices {
  final CollectionRepository<Account> accounts;
  final CollectionRepository<PaymentCard> cards;
  final CollectionRepository<TransactionCategory> categories;
  final CollectionRepository<Transaction> transactions;
  final CollectionRepository<RecurringRule> recurring;
  final SettingsController settings;
  final Ledger ledger;
  DateTime Function() clock; // padrão DateTime.now; testes injetam
}
class AppScope extends InheritedWidget {
  static AppServices of(BuildContext context); // dependOn não é necessário (serviços são estáveis)
}
```

### 6.2 `app/ledger.dart`
```dart
class Ledger extends ChangeNotifier {
  Ledger({repos..., settings, clock}); // escuta todos os repos e settings; notifica em mudança
  DateTime get today;
  Map<String, int> get accountBalances;
  Map<String, PaymentCard> get cardsById; Map<String, Account> get accountsById;
  Map<String, TransactionCategory> get categoriesById;
  List<Invoice> invoicesFor(String cardId);   // inclui projeção de recorrências
  int usedLimitFor(String cardId);
  Invoice? currentInvoiceFor(String cardId);
  Forecast get forecast;                      // horizonte = settings.forecastMonths
  Map<String?, int> spendingFor(YearMonth m);
  List<Transaction> upcoming({int days = 30}); // planned + ocorrências projetadas no período, ordenado
}
```
Cada getter é preguiçoso e memoizado; o cache inteiro é invalidado quando qualquer repo/settings notifica.

### 6.3 Ações de escrita (em `features/*/presentation/*_actions.dart` ou no próprio form)
- Salvar compra parcelada: `buildInstallments` e `transactions.upsertAll`.
- Excluir parcela: perguntar "só esta" / "todas do grupo" (`deleteWhere` por `installmentGroupId`).
- Pagar fatura: cria `Transaction(type: invoicePayment, accountId, cardId, invoiceKey, amount = remaining (editável), date = hoje, status: paid)`.
- Confirmar provisionado: `status → paid` (data editável).
- Excluir conta/cartão com transações: só arquivar (`archived = true`).

## 7. UI

Visual conforme `CLAUDE.md` (paleta, tipografia, espaçamento). Cores via `context.colors` (extensão em `core/theme/app_colors.dart`).

### 7.1 Tema — `lib/core/theme/`
- `app_colors.dart`: `class AppColors extends ThemeExtension<AppColors>` com tokens `background, surface, sidebar, primary, primarySubtle, textPrimary, textSecondary, chartBar, warning, danger, success, border` + `AppColors.light`/`AppColors.dark` (valores do CLAUDE.md; `success` = `#43A047`/`#66BB6A`; `border` = textSecondary α 0.15) + `extension AppColorsX on BuildContext { AppColors get colors; }`.
- `app_spacing.dart`: `AppSpace.xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`; `AppRadius.card=8, chip=4` (+ `BorderRadius` prontos).
- `app_palettes.dart`: `const List<int> kEntityColors` (10 cores ARGB para contas/cartões/categorias) e `const List<int> kCategoryIcons` (codepoints de `Icons.*` comuns — use `Icons.x.codePoint`). Única exceção permitida a valores fixos.
- `app_theme.dart`: `ThemeData AppTheme.light()` / `AppTheme.dark()` — Material 3, `extensions: [AppColors.x]`, `scaffoldBackgroundColor`, `cardTheme` (radius 8, elevation 0, borda), `inputDecorationTheme` (outline, dense), `dividerTheme`, `textTheme` (títulos 18 w600, seções 14 w600, corpo 13, apoio 12).

### 7.2 Widgets compartilhados — `lib/core/widgets/`
`MoneyText(int cents, {style, signed, colorBySign})` (respeita `hideValues`), `SectionCard(title, trailing, child)`,
`EmptyState(icon, message, action?)`, `LimitBar(used, limit)` (cor muda: <70% primary, <90% warning, ≥90% danger),
`StatusBadge(label, color)`, `MonthSelector(value, onChanged)`, `MoneyField(controller, label)`,
`DateField(value, onChanged, label)`, `confirmDialog(context, title, message) → Future<bool>`,
`PlannedMarker` (ícone relógio + itálico para provisionados), `KpiTile(label, cents, color?)`.

### 7.3 Shell e telas
`HomeShell`: largura ≥ 900 → sidebar fixa 220px (`colors.sidebar`) com itens ícone+rótulo, item ativo com `primarySubtle`, rodapé com toggle "Modo: Simples/Ultra"; Ultra mostra badge de contagem (faturas vencidas/pendências). < 900 → `AppBar` + `Drawer` com os mesmos itens.
Páginas (índice): 0 Painel, 1 Previsão, 2 Cartões, 3 Contas, 4 Transações, 5 Recorrentes, 6 Categorias, 7 Ajustes.
Botão global "Nova transação" (FAB / botão no cabeçalho).

| Tela | Simples | Ultra |
|---|---|---|
| Painel | KPIs (saldo atual, a pagar 30 dias, fim do mês previsto), próximas faturas (valor), próximos vencimentos | + barra de limite, gráfico de barras por categoria, alerta de saldo negativo detalhado por conta |
| Previsão | cards por mês (entradas, saídas, faturas, saldo final) | + gráfico de linha do saldo diário, tabela de eventos filtrável por conta/tipo |
| Cartões | lista por banco, fatura atual | + limite usado/total, badge "N assinaturas", detalhe com faturas passadas/futuras e itens |
| Contas | saldo atual | + saldo previsto fim do mês, transferência |
| Transações | 3 colunas (data, descrição, valor), filtro por mês | 5+ colunas, filtros banco/cartão/conta/categoria/tipo, busca, toggle provisionados, rodapé com totais |
| Recorrentes | lista e total mensal | + separação assinaturas, custo anual |
| Categorias | lista | + orçamento e barra de consumo do mês |
| Ajustes | modo, tema, ocultar valores | + horizonte de previsão, backup JSON (exportar/importar), CSV, apagar dados |

Linhas provisionadas: itálico + `PlannedMarker` + fundo `warning` α 0.08. Passadas: `textSecondary`.

### 7.4 Onboarding
Uma tela: escolher modo (Simples/Ultra) + checkbox "Criar dados de exemplo" (fictícios: "Banco Alfa", "Banco Beta"; nunca bancos reais). Grava `onboardingDone`.

## 8. Testes
- Unitários obrigatórios para todo `domain/` e `core/utils|models|services`.
- `test/` espelha `lib/` (`test/features/cards/domain/invoice_cycle_test.dart`).
- Widget smoke test: app sobe com `MemoryRecordStore` e navega pelas 8 páginas sem exceção.
- Portão: `bash tool/check.sh` → `CHECK OK`.
