# FinMe v2 — Especificação

> Fonte da verdade de domínio e arquitetura. Coders seguem os contratos daqui à risca.
> Mudou o domínio? Atualize este arquivo primeiro (papel do `finme-planner`).
> Direção da v3 (Fases 7–12): `docs/V3_DIRECTION.md`. Em conflito, ela vence este arquivo até ele ser atualizado.

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
Plataforma: **só Windows desktop** (as demais foram removidas do projeto na v3).

## 2. Arquitetura

```
lib/
  main.dart                    # runApp(bootstrap)
  app/
    app.dart                   # FinMeApp (MaterialApp, tema, home)
    bootstrap.dart             # abre storage, cria repos, seed, materializa recorrências
    app_scope.dart             # AppServices + AppScope (InheritedWidget)
    ledger.dart                # Ledger: visões derivadas memoizadas (faturas, saldos, previsão)
    home_shell.dart            # sidebar desktop (colapsa para só ícones em janela estreita) + troca de páginas + atalhos globais
    app_shortcuts.dart         # Fase 9: intents, mapa de atalhos, guarda de campo de texto
    command_palette.dart       # Fase 9: paleta Ctrl+K (PaletteEntry, showCommandPalette)
    app_commands.dart          # Fase 9: comandos da paleta e entradas de transação
    boot_screen.dart           # skeleton exibido enquanto o bootstrap carrega (Fase 7)
    seed.dart                  # categorias padrão + dados de exemplo fictícios
  core/
    models/                    # YearMonth, AppSettings, enums globais
    services/                  # RecordStore, CollectionRepository, SettingsController
    theme/                     # AppColors (ThemeExtension), AppTheme, AppText/AppFonts, AppSpace, AppRadius, AppMotion, paletas
    utils/                     # formatters, date_utils, id, text_normalize (Fase 8), fuzzy (Fase 9)
    widgets/                   # widgets compartilhados (MoneyText, SectionCard, ...)
  features/
    accounts/{domain,presentation}
    cards/{domain,presentation}
    categories/{domain,presentation}
    transactions/{domain,presentation}
    recurring/{domain,presentation}
    forecast/{domain,presentation}
    rules/{domain,presentation}        # Fase 8: regras de categorização/renomeação
    importing/{domain,presentation}    # Fase 8: CSV/OFX, categorização em cascata, prévia
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
- `String formatPercent(double ratio, {int decimals = 1})` (Fase 7): `0.1234` → `"12,3%"`, `-0.05` → `"-5,0%"`, `0` → `"0,0%"`; vírgula decimal, arredondamento meio-para-cima.

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
**Import de backup tudo-ou-nada (Fase 6, T-040).** Hive não tem transação entre boxes; o import usa compensação:
1. Valida e converte tudo antes de gravar (`_parse`); erro → `FormatException`, nada muda (já era assim).
2. Tira um retrato do estado atual: `all` de cada repositório (listas imutáveis) e `settings.value`.
3. Grava coleções, configurações e roda `materializeRecurring` dentro de `try`.
4. Qualquer exceção → restaura cada repositório com `replaceAll(retrato)` e `settings.update((_) => retrato)`,
   cada restauração no seu próprio `try` (uma falha não impede as outras), e relança o erro original (`Error.throwWithStackTrace`).
Memória e disco voltam ao estado anterior. Limite: se o próprio disco falhar também na restauração, o estado pode ficar
parcial; o erro original sobe para a UI ("Erro ao importar").

Boxes Hive (nomes novos, ignoram dados antigos): `fm_accounts`, `fm_cards`, `fm_categories`, `fm_transactions`, `fm_recurring`, `fm_settings`.
Fase 8: `fm_rules` (`TransactionRule`, §4.6), `fm_import_profiles` (`ImportProfile`, §4.7), `fm_dictionary` (`DictionaryEntry`, §4.8).
No boot, `fm_dictionary` vazia é semeada com `defaultDictionary()` (§5.13). Shortcut: apagar todas as entradas do dicionário
faz o padrão voltar no próximo boot (equivale a "restaurar padrão").

**Backup e as boxes da Fase 8.** `exportJson` grava também `'rules'`, `'importProfiles'` e `'dictionary'` (listas de `toMap()`).
`BackupService.version` continua `1`. No import: chave ausente (backup antigo) → `rules = []`, `importProfiles = []`,
`dictionary = defaultDictionary()`. Perfil cujo `accountId`/`cardId` não existe no backup é descartado (`_linked`);
regra com `categoryId` ausente no backup fica com `categoryId: null` (`_unlinkedCategory`). As três coleções entram no
retrato e na restauração do import tudo-ou-nada. "Apagar todos os dados" (Ajustes) faz `rules.replaceAll([])`,
`importProfiles.replaceAll([])` e `dictionary.replaceAll(defaultDictionary())`.

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

### 3.7 Normalização de texto — `lib/core/utils/text_normalize.dart` (Fase 8)
Dart puro, usado por regras, histórico, dicionário e deduplicação.
```dart
String foldText(String s);
  // maiúsculas; sem acento (ÁÀÂÃÄ→A, ÉÈÊË→E, ÍÌÎÏ→I, ÓÒÔÕÖ→O, ÚÙÛÜ→U, Ç→C, Ñ→N, idem minúsculas);
  // espaços (inclui \t e U+00A0) colapsados em um; trim. Pontuação é mantida.
String normalizeDescription(String s); // chave de histórico/dedupe (regras abaixo)
Set<String> descriptionTokens(String normalized);
  // split por espaço; remove tokens com < 2 caracteres e os de kStopTokens
double jaccard(Set<String> a, Set<String> b); // |a∩b| / |a∪b|; ambos vazios → 0.0
bool similarDescriptions(String a, String b);
  // ka = normalizeDescription(a), kb = normalizeDescription(b); true se: ka == kb e não vazio;
  // ou a menor (≥ 4 caracteres) está contida na maior; ou jaccard(descriptionTokens(ka), descriptionTokens(kb)) >= 0.5
const Set<String> kStopTokens = {'PARC', 'PARCELA', 'PARCELADO', 'COMPRA', 'PAG', 'PAGTO', 'PGTO', 'PAGAMENTO',
  'DEBITO', 'CREDITO', 'CARTAO', 'LTDA', 'EIRELI', 'ME', 'SA', 'DE', 'DA', 'DO', 'DOS', 'DAS', 'COM', 'EM', 'BR'};
const Set<String> kUfTokens = {...27 siglas de UF..., 'BR', 'BRA', 'BRASIL'};
const List<String> kCitySuffixes = ['SAO PAULO', 'RIO DE JANEIRO', 'BELO HORIZONTE', 'BRASILIA', 'SALVADOR',
  'FORTALEZA', 'CURITIBA', 'RECIFE', 'PORTO ALEGRE', 'MANAUS', 'BELEM', 'GOIANIA', 'CAMPINAS', 'FLORIANOPOLIS',
  'VITORIA', 'NATAL', 'JOAO PESSOA', 'OSASCO', 'SANTOS', 'GUARULHOS'];
```
`normalizeDescription`, em ordem:
1. `foldText`.
2. Remove datas `\b\d{1,2}[/.-]\d{1,2}([/.-]\d{2,4})?\b` e marcadores "N DE M" `\b\d{1,2}\s+DE\s+\d{1,2}\b` (troca por espaço).
3. Todo caractere fora de `[A-Z0-9 ]` vira espaço (some `*`, `-`, `.`, `/`).
4. Quebra em tokens; descarta tokens que contêm dígito (códigos, números de pedido) e `PARC`/`PARCELA`/`PARCELADO`.
5. Até 3 vezes: remove tokens finais em `kUfTokens`; remove um sufixo final igual a um item de `kCitySuffixes`.
   Nunca deixa a lista vazia: se a remoção esvaziaria, para antes.
6. `join(' ')`. Pode resultar em `''` (ex.: só dígitos) → chave vazia não casa nada no histórico.
Exemplos (teste obrigatório): `'UBER *TRIP 8X7Y2 SAO PAULO BR'` → `'UBER TRIP'`; `'IFOOD*RESTAURANTE 12/11'` → `'IFOOD RESTAURANTE'`;
`'Farmácia São João 0412'` → `'FARMACIA SAO JOAO'`; `'LOJA EXEMPLO PARC 03/10'` → `'LOJA EXEMPLO'`;
`'LOJA EXEMPLO 03 DE 10'` → `'LOJA EXEMPLO'`; `'PADARIA PAO BOM CURITIBA PR'` → `'PADARIA PAO BOM'`; `'123456'` → `''`; `'SP'` → `'SP'`.

### 3.8 Busca aproximada — `lib/core/utils/fuzzy.dart` (Fase 9)
Dart puro. Usada pela paleta de comandos (§7.3 "Produtividade") e pela busca de transações (§5.17). Reusa `foldText` (§3.7).
```dart
List<String> foldedWords(String folded);
  // split de um texto JÁ dobrado por RegExp(r'[^A-Z0-9]+'), sem vazios. foldedWords('UBER *TRIP 8X') == ['UBER', 'TRIP', '8X']
int? fuzzyTokenScore(String token, String folded, List<String> words);
  // token e folded JÁ dobrados; words = foldedWords(folded). Primeira regra que vale:
  // folded.startsWith(token) → 4; algum word.startsWith(token) → 3; folded.contains(token) → 2;
  // token.length >= 3 e token é subsequência de folded (caracteres na ordem, não contíguos) → 1; senão null.
int? fuzzyScore(String query, String text);
  // tokens = foldText(query).split(' ') sem vazios; sem tokens → 0.
  // f = foldText(text); soma de fuzzyTokenScore(token, f, foldedWords(f)); qualquer token null → null.
List<T> fuzzyRank<T>(Iterable<T> items, String query, Iterable<String> Function(T item) texts, {int? limit});
  // score do item = maior fuzzyScore(query, x) entre texts(item); itens com score null saem.
  // Ordena por score desc, empate mantém a ordem de entrada (ordenação estável). Query vazia → itens na ordem de entrada.
  // limit != null → take(limit).
```
Exemplos (teste obrigatório): `fuzzyScore('', 'x') == 0`; `fuzzyScore('nova', 'Nova transação') == 4`; `('trans', 'Nova transação') == 3`;
`('ansa', 'Nova transação') == 2`; `('nvt', 'Nova transação') == 1`; `('nv', 'Nova transação') == null` (subsequência exige 3+);
`('xyz', 'Nova transação') == null`; `('ir pain', 'Ir para Painel') == 7`; `('cafe', 'Café da manhã') == 4`.

## 4. Entidades de domínio

Todas imutáveis, com `copyWith`, `toMap`, `factory fromMap`.
**`copyWith` e campos anuláveis (Fase 6, T-042/T-043):** todo parâmetro de campo anulável usa sentinela privada
`const Object _keep = Object();` por arquivo, com assinatura `Object? campo = _keep`. Omitido → mantém;
`campo: null` → limpa; valor → troca (`campo == _keep ? this.campo : campo as Tipo?`). Campos não anuláveis seguem `Tipo? campo` + `??`.
Nenhuma chamada existente passa `null` explícito, então o comportamento atual não muda. Vale para `PaymentCard.paymentAccountId`,
`TransactionCategory.monthlyBudgetCents`, os 10 anuláveis de `Transaction` (`categoryId`, `accountId`, `cardId`, `toAccountId`,
`invoiceKey`, `installmentGroupId`, `installmentIndex`, `installmentCount`, `recurringId`, `notes`) e `RecurringRule`
(`categoryId`, `accountId`, `cardId`, `endDate`, `materializedUntil`). `Account` e `AppSettings` não têm anuláveis.
Os formulários continuam recriando pelo construtor (sem mudança obrigatória).
Enums serializados por `name`;
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
  int colorValue, bool archived,
  List<CardCycle> cycleHistory, // padrão const []; ciclos ANTERIORES, ordenados por `until` asc (Fase 5)
}
class CardCycle {           // mesmo arquivo; ==/hashCode por campos
  const CardCycle({required this.until, required this.closingDay, required this.dueDay});
  final DateTime until;     // exclusivo, dateOnly: vale para compras com data < until
  final int closingDay, dueDay;
  Map<String, dynamic> toMap();  // {'until': dateKey(until), 'closingDay', 'dueDay'}
  factory CardCycle.fromMap(Map<String, dynamic> m); // until via parseDateKey
}
// Em PaymentCard:
({int closingDay, int dueDay}) cycleOn(DateTime date);
  // 1º item de cycleHistory com dateOnly(date) < until → seus dias; senão (closingDay, dueDay) atuais.
PaymentCard withCycleChange({required int closingDay, required int dueDay, required DateTime effectiveFrom});
  // dias iguais aos atuais → this. Senão: cycleHistory + CardCycle(until: dateOnly(effectiveFrom),
  // closingDay: this.closingDay, dueDay: this.dueDay), e closingDay/dueDay novos.
  // ArgumentError se effectiveFrom <= último until do histórico.
```
- `closingDay`/`dueDay` continuam sendo o ciclo **atual** (vigente a partir do último `until`, ou sempre se o histórico é vazio): todos os chamadores existentes seguem válidos.
- `toMap` grava `cycleHistory` como lista de mapas; `fromMap` tolera chave ausente, `null` ou item inválido (ignora o item) → sem migração de box. Backups antigos importam normalmente.
- `copyWith` aceita `cycleHistory`; `==`/`hashCode` comparam a lista elemento a elemento (sem `package:flutter` — use loop ou `Object.hashAll`).

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
  String? externalId;          // Fase 8: FITID do OFX (deduplicação forte); null em manual/CSV
  String? importedDescription; // Fase 8: descrição como veio do arquivo; null em lançamento manual
}
```
Fase 8: `externalId` e `importedDescription` são anuláveis com sentinela `_keep` no `copyWith`, entram em `toMap` só quando
não nulos e `fromMap` tolera ausência (sem migração). `==`/`hashCode` incluem os dois. Regras e histórico leem o
"assunto" da transação: `ruleSubject(t) = t.importedDescription ?? t.description` (assim renomear não apaga o que casa).
Regras:
- Construtor normaliza `date` com `dateOnly` (não é `const`). Idem `RecurringRule.startDate/endDate`.
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
  bool isSubscription, bool isBoleto, bool active,
  DateTime? materializedUntil   // última data já materializada no boot (evita ressuscitar ocorrência apagada)
}
```

### 4.6 `features/rules/domain/transaction_rule.dart` (Fase 8)
```dart
enum RuleMatchType { contains, startsWith, regex }
class TransactionRule {
  const TransactionRule({required this.id, required this.pattern, this.matchType = RuleMatchType.contains,
    this.categoryId, this.renameTo, this.priority = 0, this.active = true});
  final String id;
  final String pattern;          // texto (contains/startsWith) ou expressão regular
  final RuleMatchType matchType;
  final String? categoryId;      // categoria a aplicar (null = só renomeia)
  final String? renameTo;        // descrição final (null/vazio = não renomeia)
  final int priority;            // menor vence; empate por id asc
  final bool active;
}
```
`copyWith` com `_keep` para `categoryId`/`renameTo`; `toMap`/`fromMap` (enum desconhecido → `contains`, `priority` ausente → 0,
`active` ausente → true); `==`/`hashCode` por campos. Uma regra útil tem `categoryId != null` ou `renameTo` não vazio (validado na UI).
Tags ficam para a Fase 10 (campo não existe ainda; `fromMap` tolerante permite acrescentar depois sem migração).

### 4.7 `features/importing/domain/import_profile.dart` (Fase 8)
Perfil salvo de importação (mapeamento CSV ou destino OFX), reaplicável com 1 clique.
```dart
enum ImportFormat { csv, ofx }
enum DateOrder { dmy, mdy, ymd }          // dd/mm/aaaa, mm/dd/aaaa, aaaa-mm-dd (qualquer separador / . -)
enum DecimalMark { comma, dot }
enum InstallmentDateMode { posting, purchase } // data da linha de parcela = lançamento na fatura | compra original
class ImportProfile {
  const ImportProfile({required this.id, required this.name, this.format = ImportFormat.csv,
    this.accountId, this.cardId, this.delimiter = ';', this.skipRows = 1, this.dateColumn = 0,
    this.descriptionColumn = 1, this.amountColumn = 2, this.debitColumn, this.creditColumn, this.categoryColumn,
    this.dateOrder = DateOrder.dmy, this.decimalMark = DecimalMark.comma, this.invertSign = false,
    this.installmentDateMode = InstallmentDateMode.posting, this.categoryMap = const {}});
  final String id, name;
  final ImportFormat format;
  final String? accountId, cardId;       // destino: exatamente um
  final String delimiter;                // 1 caractere: ';' ',' '\t' '|'
  final int skipRows;                    // linhas antes dos dados (inclui o cabeçalho)
  final int dateColumn, descriptionColumn; // 0-based
  final int? amountColumn;               // valor único com sinal …
  final int? debitColumn, creditColumn;  // … ou débito/crédito separados
  final int? categoryColumn;             // opcional
  final DateOrder dateOrder;
  final DecimalMark decimalMark;
  final bool invertSign;                 // fatura de cartão com compras positivas
  final InstallmentDateMode installmentDateMode;
  final Map<String, String> categoryMap; // foldText(categoria do banco) → categoryId (de-para)
  String? get mappingError;
  ImportProfile learnBankCategories(Map<String, String> learned); // acrescenta só chaves novas
}
```
`mappingError` (null = válido), na ordem: destino ausente ou duplo → `'Escolha a conta ou o cartão'`; formato CSV e não
(`amountColumn != null` XOR (`debitColumn != null || creditColumn != null`)) → `'Use valor único ou débito/crédito'`;
CSV com colunas definidas repetidas ou negativas → `'Colunas repetidas ou inválidas'`; `delimiter.length != 1` →
`'Separador inválido'`; `skipRows < 0` → `'Linhas a pular inválidas'`. Para OFX só o destino é validado.
`copyWith` com `_keep` para `accountId`, `cardId`, `amountColumn`, `debitColumn`, `creditColumn`, `categoryColumn`.
`toMap` grava `categoryMap` como mapa; `fromMap` tolera ausência de qualquer campo (padrões acima). `==` compara o mapa por conteúdo.

### 4.8 `features/importing/domain/merchant_dictionary.dart` — `DictionaryEntry` (Fase 8)
```dart
class DictionaryEntry {
  const DictionaryEntry({required this.id, required this.pattern, required this.categoryName});
  final String id;
  final String pattern;       // guardado já em foldText (ex.: 'UBER', 'PAO DE ACUCAR', 'APPLE.COM')
  final String categoryName;  // nome da categoria (resolvido por nome, §5.13)
  // copyWith, toMap, fromMap, ==/hashCode
}
```
Guarda nome e não id: o dicionário embutido precisa funcionar com qualquer conjunto de categorias e sobreviver a backups.

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

**Histórico de ciclo (Fase 5).** Mudar fechamento/vencimento vale a partir de uma data, sem reescrever faturas passadas
(senão pagamentos antigos, ligados por `invoiceKey`, cairiam em faturas erradas e reabririam faturas quitadas).
Assinaturas finais:
```dart
YearMonth invoiceDueMonth(DateTime purchase, PaymentCard card);
  // sem histórico: regra acima. Com histórico: linha de fechamentos (abaixo, Fase 6)
DateTime invoiceClosingDate(YearMonth dueMonth, PaymentCard card, {DateTime? cycleDate});
DateTime invoiceDueDate(YearMonth dueMonth, PaymentCard card, {DateTime? cycleDate});
  // com histórico: datas do fechamento do mês (regra 7 abaixo); fallback c = card.cycleOn(cycleDate ?? dueMonth.firstDay)
DateTime purchaseDueDate(DateTime purchase, PaymentCard card);
  // vencimento do fechamento que recebe a compra (regra 8 abaixo)
```
Sem histórico, `cycleOn` devolve sempre o ciclo atual → comportamento idêntico ao anterior (testes de T-006 passam sem mudança).

**Linha de fechamentos e fatura de transição (Fase 6, T-044 — substitui a fusão de faturas).**
Com `cycleHistory` não vazio, a fatura é o período entre dois fechamentos consecutivos, como no banco.
A data efetiva (`until`) de uma mudança significa "o primeiro fechamento no dia novo é o primeiro em ou após esta data".
1. **Segmentos.** `cycleHistory[i]` vale em `[cycleHistory[i-1].until, cycleHistory[i].until)` (o 1º, desde sempre);
   o ciclo atual (`closingDay`/`dueDay`) vale em `[último until, ∞)`.
2. **Fechamentos de um segmento** `(cl, du)`: para cada mês `m`, `C = m.dateAt(cl)`, mantido se `from <= C < until`.
   Vencimento de `C`: `dueMonth = du > cl ? YearMonth.fromDate(C) : YearMonth.fromDate(C).next()`, `dueDate = dueMonth.dateAt(du)`.
3. **Sequência.** Fechamentos de todos os segmentos em ordem crescente de data. **Descarta** o fechamento cujo
   `dueMonth` seja `<=` o `dueMonth` do último fechamento mantido. Assim cada `dueMonth` tem no máximo um fechamento:
   não existe fusão. A fatura de transição só fica com um período mais longo.
4. **Compra/estorno** com data `d` → primeiro fechamento mantido `C` com `d < C` (compra no dia do fechamento vai para o próximo).
   `invoiceDueMonth(d, card)` = `dueMonth` de `C`.
5. **Fatura de transição** = a do primeiro fechamento mantido do segmento novo. Período: do último fechamento antigo
   (exclusivo) até esse fechamento (exclusivo, pela regra 4). Os itens dela têm todos o mesmo vencimento.
6. **Parcelas.** Parcela `i` de um grupo cuja 1ª parcela tem data `d1` → o fechamento mantido `i - 1` posições depois
   do fechamento de `d1`. Sem histórico, equivale a `invoiceDueMonth(d1, card).addMonths(i - 1)`.
7. **Datas da fatura.** `invoiceClosingDate`/`invoiceDueDate(M, card, {cycleDate})`: se existe fechamento mantido com
   `dueMonth == M` → sua data / seu vencimento (independem dos itens). Senão (mês sem fechamento, ex.: fatura só com
   pagamento antigo) → regra anterior com `card.cycleOn(cycleDate ?? M.firstDay)`.
8. `purchaseDueDate(d, card)` = vencimento do fechamento da regra 4 → sempre igual ao `dueDate` da fatura que recebe a compra.
9. **Atalho:** histórico vazio → fórmulas originais (sem gerar sequência).
10. **Janela de cálculo:** gere fechamentos de `min(mês(d), mês(cycleHistory.first.until)).addMonths(-1)` até
    `mês(d).addMonths(n + 2)` (`n` = parcelas à frente; 0 para compra simples). A janela começa antes da primeira
    fronteira, então contém todas as fronteiras anteriores a `d`; dentro de um segmento os `dueMonth` só crescem, logo o
    descarte dá o mesmo resultado que a sequência completa.

Exemplos (todas as datas de 2026, salvo indicação):
- Fecha 5/vence 12 → fecha 25/vence 5 a partir de 01/12. Fechamentos: …05/11 (nov), 25/12 (jan/2027), 25/01/2027 (fev).
  Compra 04/11 → `2026-11`, vence 12/11. Compras 20/11 e 02/12 → `2027-01`, vence 05/01/2027 (fatura de transição 05/11–25/12).
  Não existe fatura `2026-12`. Parcelado 3x com 1ª em 15/10 → `2026-11`, `2027-01`, `2027-02`.
  Pagamento com `invoiceKey` `2026-11` continua quitando nov.
  Pagamento com `invoiceKey` `2026-12` (sem fechamento mantido) → `invoiceMonthForKey` = `2027-01`: abate a fatura de transição.
- Fecha 5/vence 12 → fecha 20/vence 27 a partir de 15/11. Fechamento 20/11 venceria em nov (= nov do 05/11) → descartado.
  Compras 04/11 → nov (12/11). Compras 10/11 e 16/11 → `2026-12`, fecha 20/12, vence 27/12 (transição 05/11–20/12).
  `invoiceDueDate(2026-12)` = 27/12 com ou sem itens.
- Fecha 25/vence 5 → fecha 5/vence 12 a partir de 01/12. 25/11 → dez (05/12). 05/12 venceria em dez → descartado.
  Compra 24/11 → `2026-12` (05/12). Compra 28/11 → `2027-01`, fecha 05/01/2027, vence 12/01/2027.

11. **Pagamento (`invoicePayment`) com `invoiceKey` K** → `invoiceMonthForKey(K, card)`: se K tem fechamento mantido, K;
    senão, `dueMonth` do primeiro fechamento mantido posterior ao fim do mês K-1 (= o primeiro com vencimento > K).
    Assim o pagamento abate a fatura de transição e não vira fatura só de pagamento. Sem histórico, K.

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
  }); // agrupa expense(+)/income(-) por invoiceDueMonth; invoicePayment soma em paidCents pelo invoiceMonthForKey(invoiceKey) (§5.1 regra 11); ordena por dueMonth
  static int usedLimitCents(Iterable<Invoice> invoices, DateTime today);
    // soma remainingCents das faturas com status != paid (inclui parcelas futuras)
  static Invoice? currentInvoice(Iterable<Invoice> invoices, DateTime today);
    // fatura não paga mais antiga (inclusive vencida); se todas pagas, null
}
```
Só cartões `credit` têm faturas.
Datas da fatura com histórico de ciclo (Fase 6): `closingDate`/`dueDate` = `invoiceClosingDate`/`invoiceDueDate(dueMonth, card, cycleDate: …)`
pela regra 7 do §5.1. `cycleDate` (maior `t.date` dos itens; sem itens, `dueMonth.firstDay`) só é usado quando o mês não tem fechamento.
Mês das parcelas: `installmentDueMonth(dataDa1ª, index, card)` (§5.1 regra 6), exposto em `invoice_cycle.dart`:
```dart
YearMonth installmentDueMonth(DateTime firstDate, int index, PaymentCard card); // index 1-based
```

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
  // status: cardId != null → paid. Conta: forProjection → planned;
  // materialização (forProjection: false) → paid se date < to && !isBoleto, senão planned
  // (boleto exige confirmação; ocorrência de hoje fica provisionada).
```
No boot e na virada de dia (`materializeRecurring`): materializa ocorrências de
`max(startDate, materializedUntil + 1 dia)` até **ontem** (`forProjection: false`, `to = ontem + 1 dia`
para a regra de status → tudo < hoje), grava, e atualiza `materializedUntil = ontem`.
A ocorrência de hoje em diante aparece só pela projeção. Ocorrências futuras **não** são gravadas: entram na previsão via projeção.

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
    int minDays = 0, // Fase 6 (T-041): horizonte cobre pelo menos today + minDays
  });
}
```
Algoritmo:
1. `currentBalances` = `accountBalances(...)` (contas não arquivadas); `currentTotal` = soma.
2. Horizonte: `today` até `end` = o mais tarde entre `YearMonth.fromDate(today).addMonths(months - 1).lastDay` e
   `DateTime(today.year, today.month, today.day + minDays)`. `months` continua com exatamente `months` entradas
   (eventos após o último mês entram em `events`/`daily`, mas não em `months`). `minDays = 0` → comportamento anterior.
3. Eventos:
   - Transações `planned` de conta (income/expense/transfer, inclusive débito) com data ≤ fim. Atrasadas (data < today) entram **em today**. `isBoleto` → kind `boleto`.
   - Recorrências: `occurrenceTransactions(r, today, fim, idsExistentes, forProjection: true)`. De conta → evento (`isProjected: true`). De cartão de crédito → vão para `projected` da fatura.
   - Faturas: para cada cartão de crédito, `InvoiceService.build(card, transactions, projected)`; cada fatura com `remainingCents > 0` e `dueDate ≤ fim` gera evento `invoice` de `-remaining` em `max(dueDate, today)` na conta `card.paymentAccountId` (pode ser `null`: conta só no consolidado).
4. `transfer` não entra em income/expense mensal e tem efeito zero no consolidado.
5. `months[i]`: soma por mês de eventos; `endBalanceCents` = saldo consolidado no último dia do mês.
6. `daily`: saldo consolidado acumulado dia a dia; `firstNegativeDate` = primeiro dia < 0.
   `accountNegativeDates` análogo por conta.
Desempenho: O(n) sobre transações por cartão (agrupe por `cardId` uma vez).

### 5.8 Insights de cartão — `features/cards/domain/card_insights.dart` (Fase 5)
```dart
class CardPurchaseOption {
  const CardPurchaseOption({required this.card, required this.dueDate, required this.daysUntilDue, required this.freeLimitCents});
  final PaymentCard card;
  final DateTime dueDate;      // purchaseDueDate(today, card)
  final int daysUntilDue;      // dias corridos today → dueDate (calcule com DateTime.utc para evitar horário de verão)
  final int freeLimitCents;    // card.limitCents - usado (pode ser <= 0; limite 0 = não informado)
  bool get hasLimit => freeLimitCents > 0;
}
List<CardPurchaseOption> bestCardsToBuy({
  required Iterable<PaymentCard> cards,
  required Map<String, int> usedLimitByCard, // ausente → 0
  required DateTime today,
});
  // só kind == credit && !archived. Ordem: hasLimit (true antes), daysUntilDue desc,
  // freeLimitCents desc, card.name asc.

class InstallmentCommitment {
  const InstallmentCommitment({required this.month, required this.byCard});
  final YearMonth month;            // mês de vencimento da fatura
  final Map<String, int> byCard;    // cardId → centavos; omite cartões com 0
  int get totalCents;               // soma de byCard
}
List<InstallmentCommitment> installmentCommitments({
  required Iterable<Invoice> invoices, // faturas de todos os cartões de crédito
  required YearMonth from,
  int months = 12,
});
  // exatamente `months` entradas (from .. from+months-1), inclusive zeradas.
  // por fatura com dueMonth no intervalo: soma itens com installmentGroupId != null
  // (expense +, income −) em byCard[invoice.card.id]. Ignora pagamentos e itens sem grupo
  // (compras à vista e recorrências projetadas não são "compromisso de parcela").

List<PaymentCard> cardsWithoutPaymentAccount(Iterable<PaymentCard> cards, Set<String> activeAccountIds);
  // !archived && (paymentAccountId == null || !activeAccountIds.contains(paymentAccountId)); mantém ordem de entrada.
```
Exemplo (hoje 14/11/2026): A fecha 5/vence 12 → vence 12/12 (28 dias); B fecha 25/vence 5 → 05/12 (21);
C fecha 20/vence 27 → 27/11 (13). Ordem A, B, C — exceto se A não tiver limite livre (vai para o fim).

### 5.9 Linha do tempo de vencimentos e cobertura — `features/forecast/domain/invoice_timeline.dart` (Fase 5)
```dart
class InvoiceDue {
  const InvoiceDue({required this.invoice, required this.date, required this.amountCents,
                    this.accountId, this.accountBalanceAfterCents});
  final Invoice invoice;
  final DateTime date;                 // data do evento de previsão = max(invoice.dueDate, today)
  final int amountCents;               // > 0 (remaining previsto)
  final String? accountId;             // conta de pagamento ativa; null = sem conta (ou arquivada)
  final int? accountBalanceAfterCents; // saldo previsto da conta ao FIM de `date`; null se accountId null
  bool get overdue => invoice.dueDate.isBefore(date);
  bool get hasAccount => accountId != null;
  bool get uncovered => accountBalanceAfterCents != null && accountBalanceAfterCents! < 0;
  bool get needsAttention => !hasAccount || uncovered;
}
List<InvoiceDue> invoiceTimeline({
  required Forecast forecast,
  required Iterable<Invoice> invoices, // para resolver ForecastEvent.sourceId == Invoice.id
  int days = 60,
});
```
Algoritmo (uma passada, O(eventos)):
1. `limit = forecast.today + days` (inclusivo). Saldos por conta começam em `forecast.currentBalances`.
2. Percorre `forecast.events` (já ordenados) agrupados por data; aplica **todos** os eventos do dia às contas
   (`accountId != null`) e só então emite um `InvoiceDue` por evento `kind == invoice` do dia,
   com `accountBalanceAfterCents = saldo[accountId]`. Para ao passar de `limit`.
3. Evento cujo `sourceId` não está em `invoices` é ignorado. Saída na ordem dos eventos.
Duas faturas no mesmo dia na mesma conta têm o mesmo saldo-após (fim do dia).
`forecastMonths = 3` com hoje em 31/01 dá horizonte até 31/03 (59 dias): por isso o Ledger chama a previsão com
`minDays: Ledger.invoiceTimelineDays` (60), garantindo que o limite inclusivo `today + 60` esteja no horizonte (Fase 6, T-041).

### 5.10 Histórico mensal e variação — `features/accounts/domain/monthly_history.dart` (Fase 7)
Alimenta delta vs. mês anterior e sparklines dos KPIs do Painel (só Modo Ultra).
```dart
class MonthSnapshot {
  const MonthSnapshot({required this.month, required this.endBalanceCents, required this.expenseCents});
  final YearMonth month;
  final int endBalanceCents; // saldo consolidado das contas ativas ao fim do mês
  final int expenseCents;    // despesas pagas do mês (regra de spendingByCategory, sem provisionados)
}
List<MonthSnapshot> monthlyHistory({
  required Iterable<Account> accounts,
  required Iterable<PaymentCard> cards,
  required Iterable<Transaction> transactions,
  required DateTime today,
  int months = 6,
}); // ordem cronológica; length == months; último = mês de today
int expenseUntilDay(Iterable<Transaction> txs, YearMonth month, int day);
double? deltaRatio(int previous, int current);
```
Regras:
1. Contas ativas = `!archived` (mesma base de `Forecast.currentTotalCents`). Transações provisionadas nunca contam.
2. `endBalanceCents` de mês passado = soma, nas contas ativas, de `initialBalanceCents` + `signedEffectOn` de toda transação não provisionada com `date <= month.lastDay`.
   O **último** snapshot (mês atual) usa todas as transações não provisionadas, sem corte por data: fica igual a `Forecast.currentTotalCents` (o KPI "Saldo atual").
3. `expenseCents` = soma de `spendingByCategory(txs, month).values`; no mês atual, só transações com `date <= today`.
4. `expenseUntilDay(txs, month, day)`: despesas pagas do mês com `date.day <= min(day, month.daysInMonth)`. Usado para comparar o mês atual com o mesmo período do mês anterior.
5. `deltaRatio(previous, current)`: `previous == 0` → `null`; senão `(current - previous) / previous.abs()` (ex.: 1000 → 1500 = 0.5; -1000 → -500 = 0.5; 1000 → 0 = -1.0).
6. Custo O(T × meses) no pior caso; chamado só pelo Ledger (memoizado).

### 5.11 Linha importada e parsers — `features/importing/domain/` (Fase 8)
Tudo Dart puro. `package:csv` é permitido em `domain/` (é Dart puro).
```dart
// imported_line.dart
class ImportedLine {
  const ImportedLine({required this.row, required this.date, required this.description,
    required this.amountCents, this.fitid, this.bankCategory});
  final int row;             // 1-based: linha do arquivo (CSV) ou ordem do STMTTRN (OFX)
  final DateTime date;       // dateOnly
  final String description;  // trim, nunca vazia (vazia → erro da linha)
  final int amountCents;     // com sinal: + entrada, − saída; nunca 0
  final String? fitid;       // OFX
  final String? bankCategory;// CSV, coluna de categoria (trim; vazia → null)
}
class ImportLineError { const ImportLineError(this.row, this.message); final int row; final String message; }
class ImportParseResult { const ImportParseResult(this.lines, this.errors); final List<ImportedLine> lines; final List<ImportLineError> errors; }
```

**CSV — `csv_import.dart`:**
```dart
String decodeText(List<int> bytes);
  // remove BOM UTF-8; tenta utf8.decode (allowMalformed: false); FormatException → latin1.decode.
String guessDelimiter(String text);
  // conta ';' ',' '\t' '|' fora de aspas nas 5 primeiras linhas não vazias; maior contagem vence; empate/nada → ';'
List<List<String>> readCsv(String text, {required String delimiter});
  // troca \r\n e \r por \n; CsvToListConverter(fieldDelimiter: delimiter, eol: '\n', shouldParseNumbers: false);
  // células viram String (toString + trim); remove linhas totalmente vazias do fim.
int? parseAmountCell(String raw, DecimalMark mark);
DateTime? parseDateCell(String raw, DateOrder order);
ImportParseResult parseCsvLines(List<List<String>> rows, ImportProfile profile);
```
`parseAmountCell` (sem `double`): trim; remove `R$`, espaços e U+00A0; negativo se começa com `-`, termina com `-`, está entre
parênteses ou termina com `D` (débito; `C` = crédito, removido); `comma` → remove `.` e troca `,` por `.`; `dot` → remove `,`.
Partes: inteira só dígitos; fração com 0–2 dígitos (3+ → arredonda meio-para-cima pelo 3º dígito). Inválido/vazio → `null`.
Exemplos: `('-1.234,56', comma)` → `-123456`; `('1,234.56', dot)` → `123456`; `('(10,00)', comma)` → `-1000`; `('45,9 D', comma)` → `-4590`;
`('R$ 7', comma)` → `700`; `('12,345', comma)` → `null` (fração com mais de 2 dígitos é inválida); `('abc', comma)` → `null`; `('', dot)` → `null`.
`parseDateCell`: pega o 1º token antes de espaço ou `T` (descarta hora); separa por `/ . -`; exige 3 partes numéricas;
ano com 2 dígitos → 2000+aa; valida (dia/mês reais: `DateTime(y, m, d)` com mesmo y/m/d). Inválida → `null`.
`parseCsvLines`: pula `profile.skipRows` linhas; para cada linha restante (row = índice 1-based no arquivo):
coluna ausente (linha curta) → erro `'Coluna ausente'`; data inválida → `'Data inválida'`; descrição vazia → `'Descrição vazia'`;
valor: com `amountColumn`, `parseAmountCell`; com débito/crédito: débito preenchido → `-abs`, crédito → `+abs`, ambos → `crédito − débito`,
nenhum → `'Valor inválido'`; valor `null` → `'Valor inválido'`; `invertSign` → nega; resultado 0 → `'Valor zero'`.
Erro não interrompe: a linha vai para `errors` e o resto segue.

**OFX — `ofx_parser.dart`** (SGML 1.x sem tags de fechamento e XML 2.x):
```dart
class OfxStatement { const OfxStatement({required this.isCreditCard, this.accountId, required this.result});
  final bool isCreditCard; final String? accountId; final ImportParseResult result; }
OfxStatement parseOfx(String text);
```
1. Busca sem diferenciar caixa. `isCreditCard` = existe `<CCSTMTRS>`. `accountId` = valor do 1º `<ACCTID>`.
2. Blocos: de cada `<STMTTRN>` até `</STMTTRN>`, o próximo `<STMTTRN>` ou `</BANKTRANLIST>` (o que vier antes).
3. Valor de uma tag `X` no bloco = texto após `<X>` até o próximo `<`, trim. Decodifica `&amp; &lt; &gt; &quot; &apos;`.
4. `DTPOSTED`: 8 primeiros dígitos `yyyyMMdd` (ignora hora e `[-3:BRT]`); inválido → erro `'Data inválida'`.
5. `TRNAMT`: sinal opcional; se tem `,` e `.`, o último é o decimal; só `,` → decimal vírgula; centavos sem `double`.
   Inválido → `'Valor inválido'`; 0 → `'Valor zero'`. Sinal do OFX vale como está (negativo = saída, também em cartão).
6. Descrição: `NAME` e `MEMO` não vazios; se um contém o outro (após `foldText`), usa o mais longo; senão `'NAME MEMO'`. Ambos vazios → `'Descrição vazia'`.
7. `fitid` = `FITID` (vazio → null). `row` = posição do bloco (1-based). Arquivo sem `<OFX>` → `FormatException('Arquivo OFX inválido')`.

### 5.12 Parcelas em linhas importadas — `features/importing/domain/import_installments.dart` (Fase 8)
```dart
typedef InstallmentMark = ({int index, int count});
InstallmentMark? detectInstallment(String description);
List<({int index, DateTime date})> importedInstallmentDates({
  required DateTime lineDate, required int index, required int count,
  required InstallmentDateMode mode, PaymentCard? card,
}); // entradas index..count, em ordem; a 1ª é a própria linha importada
```
`detectInstallment` (sobre `foldText`), primeiro padrão que casar:
1. `PARC(ELA)?\.?\s*(\d{1,2})\s*(/|DE)\s*(\d{1,2})` (ex.: "PARC 03/10", "PARCELA 3 DE 10", "PARC.03/10");
2. `\b(\d{1,2})\s+DE\s+(\d{1,2})\b` (ex.: "03 DE 10");
3. `(^|\s)(\d{1,2})/(\d{1,2})$` — só no **fim** da descrição e sem `/` antes do 1º número (evita datas "05/11/2026").
Válido só se `1 <= index <= count`, `2 <= count <= 99`; senão `null`. Ex.: `'LOJA X PARC 03/10'` → (3,10); `'LOJA X 3/10'` → (3,10);
`'LOJA X 03 DE 10'` → (3,10); `'LOJA X 15/11/2026'` → null; `'LOJA X 11/05'` → null (index > count); `'LOJA X 1/1'` → null (count < 2).
Risco aceito: "LOJA 05/11" no fim vira parcela 5/11 — o usuário desliga na prévia.

`importedInstallmentDates` (mês de fatura **só** via `invoice_cycle.dart`):
- `base` = `mode == posting ? lineDate : addMonthsClamped(lineDate, index - 1)`.
- Sem cartão de crédito (`card == null` ou `card.kind != credit`): `d_i = addMonthsClamped(base, i - index)`.
- Cartão de crédito:
  1. `alvo_k = posting ? invoiceDueMonth(lineDate, card) : installmentDueMonth(lineDate, index, card)`;
  2. `ancora = invoiceClosingDate(alvo_k, card) − 1 dia`;
  3. para `i` em `index..count`: `alvo_i = installmentDueMonth(ancora, i − index + 1, card)`;
     `d_i = addMonthsClamped(base, i − index)`; se `invoiceDueMonth(d_i, card) != alvo_i` → `d_i = invoiceClosingDate(alvo_i, card) − 1 dia`.
  Garante que cada parcela cai na fatura certa mesmo com fechamento em dia 29–31 e com histórico de ciclo
  (o `InvoiceService` usa a data de cada item quando o grupo não tem a parcela 1).
Exemplos (teste obrigatório): fecha 5/vence 12, posting, linha 08/11/2026 "PARC 03/10" → 8 datas, 1ª 08/11/2026 (fatura `2026-12`),
2ª 08/12/2026 (`2027-01`), última 08/06/2027. Purchase, linha 15/09/2026 "PARC 03/10" → 1ª 15/11/2026 (`2026-12`).
Fecha 31/vence 7, posting, linha 30/01/2027 "PARC 01/03" → 30/01/2027, **27/02/2027** (ajuste), 30/03/2027 (faturas fev, mar, abr de 2027).
Histórico do §5.1 (fecha 5/vence 12 → fecha 25/vence 5 a partir de 01/12/2026), posting, linha 04/11/2026 "PARC 01/03" →
faturas `2026-11`, `2027-01`, `2027-02`. Conta corrente, linha 10/01/2027 "3/4" → 10/01/2027, 10/02/2027.

### 5.13 Categorização em cascata — `features/importing/domain/` (Fase 8)
```dart
// merchant_dictionary.dart (além de DictionaryEntry)
List<DictionaryEntry> defaultDictionary(); // a partir de kDefaultDictionary; id = 'dict_' + pattern minúsculo com não-alfanum → '_'
const List<(String, String)> kDefaultDictionary = [...]; // (pattern em foldText, nome da categoria)
const Map<String, String> kDictionaryFallbacks = {'COMBUSTIVEL': 'TRANSPORTE'}; // foldText(nome) → foldText(nome)
String? resolveCategoryByName(String name, Iterable<TransactionCategory> categories);
  // categoria com foldText(name) igual; senão tenta kDictionaryFallbacks[foldText(name)]; senão null
bool dictionaryPatternMatches(String pattern, String foldedDescription);
  // contém `pattern` como palavra inteira: posição i com i == 0 ou caractere anterior fora de [A-Z0-9], e depois do padrão
  // (aceitando um 'S' final opcional de plural) vem fim do texto ou caractere fora de [A-Z]. 'MERCADO' não casa 'MERCADOPAGO';
  // marcas coladas (HBOMAX, DROGASIL...) entram no dicionário como entradas próprias.

// category_history.dart
class CategoryHistory {
  factory CategoryHistory.build(Iterable<Transaction> transactions);
  ({String categoryId, double share})? exact(String key);
  ({String categoryId, double score})? similar(String key, {double threshold = 0.5});
  static const CategoryHistory empty;
}

// categorizer.dart
enum SuggestionSource { rule, bank, history, dictionary }
class CategorizationResult {
  const CategorizationResult({this.categoryId, this.source, this.confidence = 0, this.ruleId, this.renamedDescription});
  final String? categoryId; final SuggestionSource? source; final double confidence; // 0..1
  final String? ruleId;              // regra que deu a categoria
  final String? renamedDescription;  // da 1ª regra ativa com renameTo
  static const none = CategorizationResult();
}
class Categorizer {
  Categorizer({required Iterable<TransactionRule> rules, required Iterable<TransactionCategory> categories,
    required CategoryHistory history, required Iterable<DictionaryEntry> dictionary});
  CategorizationResult categorize(String description, {required bool isIncome,
    String? bankCategory, Map<String, String> bankCategoryMap = const {}});
}
String confidenceLabel(double c); // >= 0.8 'alta', >= 0.5 'média', senão 'baixa'
```
**Categoria permitida**: existe em `categories` e `kind == (isIncome ? income : expense)`. Sugestão não permitida é ignorada e a cascata segue.
**Cascata** (para no 1º passo que der categoria permitida):
1. **Regras** (`compileRules`, §5.14): percorre por prioridade; a 1ª que casa e tem `categoryId` permitido → `rule`, confiança 1.0, `ruleId`.
   Independente da categoria, `renamedDescription` = `renameTo` da 1ª regra que casa com `renameTo` não vazio.
2. **Banco** (coluna de categoria do CSV): `bankCategoryMap[foldText(bankCategory)]` permitido → `bank`, 0.9;
   senão `resolveCategoryByName(bankCategory)` permitido → `bank`, 0.7.
3. **Histórico** (`key = normalizeDescription(description)`, não vazia): `exact` → `history`, `0.5 + 0.4 × share`;
   senão `similar` → `history`, `0.6 × score`.
4. **Dicionário**: entre as entradas que casam (`dictionaryPatternMatches(entry.pattern, foldText(description))`) com categoria
   resolvida e permitida, vence o `pattern` mais longo (empate: ordem da lista) → `dictionary`, 0.5.
5. Nada → `categoryId: null, source: null, confidence: 0` (mantendo `renamedDescription`).
Construtor pré-compila regras, resolve as categorias do dicionário uma vez e ordena entradas por tamanho desc.

**`CategoryHistory.build`**: considera só `expense`/`income` com `categoryId != null`; `key = normalizeDescription(ruleSubject(t))`;
chave vazia é ignorada. Por chave: contagem por categoria e data mais recente por categoria. `exact(key)`: categoria mais
frequente (empate → a de data mais recente; depois id asc), `share = contagem dela / total da chave`; chave ausente → null.
Índice invertido `token → chaves` (tokens de `descriptionTokens`). `similar(key)`: candidatos = chaves que dividem algum token,
ignorando tokens presentes em > 500 chaves; avalia no máximo 300 candidatos (tokens mais raros primeiro); melhor
`jaccard >= threshold` (empate → maior total de ocorrências); devolve a categoria de `exact(candidato)` com `score = jaccard`.
Custo: build O(T), consulta O(1) + O(candidatos limitados).

**Dicionário embutido** (`kDefaultDictionary`, padrões genéricos; categorias por nome das categorias padrão do seed):
- Transporte: `UBER`, `99APP`, `99 POP`, `99 TAXI`, `CABIFY`, `ESTACIONAMENTO`, `ESTAPAR`, `PEDAGIO`, `SEM PARAR`, `CONECTCAR`, `VELOE`, `METRO`, `BILHETE UNICO`.
- Combustível (fallback Transporte): `POSTO`, `COMBUSTIVEL`, `IPIRANGA`, `SHELL`.
- Alimentação: `IFOOD`, `RAPPI`, `RESTAURANTE`, `LANCHONETE`, `LANCHES`, `PADARIA`, `PANIFICADORA`, `PIZZARIA`, `BURGER`, `MCDONALDS`, `MC DONALDS`, `SUBWAY`, `STARBUCKS`, `CAFE`.
- Mercado: `SUPERMERCADO`, `MERCADO`, `ATACADAO`, `ASSAI`, `CARREFOUR`, `PAO DE ACUCAR`, `HORTIFRUTI`, `SACOLAO`.
- Saúde: `FARMACIA`, `DROGA`, `RAIA`, `PANVEL`, `PAGUE MENOS`, `HOSPITAL`, `CLINICA`, `LABORATORIO`, `ODONTO`.
- Assinaturas: `NETFLIX`, `SPOTIFY`, `DISNEY`, `PRIME VIDEO`, `AMAZON PRIME`, `HBO`, `GLOBOPLAY`, `DEEZER`, `YOUTUBE PREMIUM`, `APPLE.COM`, `PARAMOUNT`, `CRUNCHYROLL`.
- Compras: `MERCADOLIVRE`, `MERCADO LIVRE`, `AMAZON`, `SHOPEE`, `MAGALU`, `MAGAZINE LUIZA`, `ALIEXPRESS`, `SHEIN`, `AMERICANAS`, `CASAS BAHIA`, `RENNER`, `RIACHUELO`.
- Contas e serviços: `CLARO`, `VIVO`, `TELEFONICA`, `ENERGIA`, `SANEAMENTO`, `AGUA`, `INTERNET`, `ANUIDADE`, `TARIFA`, `IOF`, `SEGURO`.
- Moradia: `ALUGUEL`, `CONDOMINIO`, `IPTU`.
- Educação: `ESCOLA`, `COLEGIO`, `FACULDADE`, `UNIVERSIDADE`, `CURSO`, `UDEMY`, `ALURA`, `LIVRARIA`.
- Lazer: `CINEMA`, `CINEMARK`, `INGRESSO`, `STEAM`, `PLAYSTATION`, `XBOX`, `TEATRO`.
- Viagem: `HOTEL`, `POUSADA`, `AIRBNB`, `BOOKING`, `DECOLAR`, `LATAM`, `AZUL LINHAS`, `GOL LINHAS`, `PASSAGEM`.
- Salário: `SALARIO`, `PROVENTOS`. Rendimentos: `RENDIMENTO`, `DIVIDENDOS`.
"Mais longo vence" resolve `MERCADO LIVRE` (Compras) × `MERCADO` (Mercado) e `AMAZON PRIME` × `AMAZON`.

### 5.14 Motor de regras — `features/rules/domain/rule_engine.dart` (Fase 8)
```dart
String ruleSubject(Transaction t); // t.importedDescription ?? t.description
bool isValidRulePattern(String pattern, RuleMatchType type); // trim vazio → false; regex: compila sem erro
class CompiledRule {
  CompiledRule(this.rule);       // compila a regex uma vez; regex inválida → nunca casa
  final TransactionRule rule;
  bool matches(String description);
  // contains/startsWith: foldText(description) contém / começa com foldText(pattern.trim()); pattern vazio → false
  // regex: RegExp(pattern, caseSensitive: false).hasMatch(description) (texto original)
}
List<CompiledRule> compileRules(Iterable<TransactionRule> rules); // só active; priority asc, empate id asc
List<TransactionRule> reorderRules(List<TransactionRule> ordered); // priority = índice na lista (0..n-1)
List<Transaction> matchingTransactions(TransactionRule rule, Iterable<Transaction> txs);
  // expense/income cujo ruleSubject casa (ignora `active`, para "testar padrão"); ordem de entrada
List<Transaction> reapplyRules(List<CompiledRule> compiled, Iterable<Transaction> txs, {
  required Map<String, TransactionCategory> categoriesById, bool overwriteCategory = false});
```
`reapplyRules` devolve **só** as transações que mudam (cópias). Só `expense`/`income`. Categoria: 1ª regra que casa com `categoryId`
existente e de `kind` compatível com o tipo; aplica se `t.categoryId == null || overwriteCategory` e for diferente.
Descrição: 1ª regra que casa com `renameTo` não vazio; se `t.description != renameTo` → `description = renameTo` e
`importedDescription = t.importedDescription ?? t.description` (o texto original fica guardado e a regra continua casando).

### 5.15 Duplicatas e casamentos — `features/importing/domain/import_matcher.dart` (Fase 8)
```dart
enum ImportFlag { fitidDuplicate, probableDuplicate, existingInstallment, sameNameAmount, invoicePaymentLike }
class ImportMatch {
  const ImportMatch({this.flags = const {}, this.duplicateOf, this.plannedMatch});
  final Set<ImportFlag> flags;
  final Transaction? duplicateOf;  // existente que motivou fitid/probable/existingInstallment
  final Transaction? plannedMatch; // provisionado a confirmar
}
class ImportMatcher {
  ImportMatcher(Iterable<Transaction> existing); // monta os índices uma vez: O(T)
  ImportMatch match(ImportedLine line, {String? accountId, String? cardId, InstallmentMark? installment});
}
final RegExp kInvoicePaymentPattern; // sobre foldText: \b(PAG(TO|AMENTO)?|PGTO)\s+(DE\s+)?(FATURA|CARTAO)\b|\bPAGAMENTO\s+(RECEBIDO|EFETUADO)\b
```
`origem` = `'${accountId ?? ''}|${cardId ?? ''}'`; tipo da linha = `amountCents < 0 ? expense : income`; `valor = abs(amountCents)`.
Índices (só transações `expense`/`income`): `fitid` por `origem|externalId`; balde `origem|tipo|valor` → lista;
parcelas `origem|index/count|valor` → lista; `normalizeDescription(ruleSubject)|valor` → contagem (qualquer origem e data).
O matcher é **com estado**: uma transação existente casa com no máximo uma linha (conjunto de ids consumidos), na ordem do arquivo.
Precedência (a primeira que casar define `duplicateOf`/`plannedMatch`):
1. `fitidDuplicate`: `line.fitid != null` e existe `origem|fitid` → flag (consome).
2. `existingInstallment`: `installment != null` e existe não consumida em `origem|index/count|valor` com `similarDescriptions` → flag (consome).
3. `probableDuplicate`: no balde, transação **paga** não consumida com `|data − line.date| <= 1 dia` e `similarDescriptions(line.description, ruleSubject(t))` → flag (consome).
4. Casamento com provisionado: no balde, transação `planned` não consumida com `|data − line.date| <= 5 dias` (descrição não importa: boleto
   costuma vir com outro texto); escolhe a de menor distância (empate: menor id) → `plannedMatch` (consome). Sem flag.
Aditivas (não consomem): `sameNameAmount` se nenhuma das 1–3 casou, a chave normalizada não é vazia e o índice de nome+valor tem
contagem > 0; `invoicePaymentLike` se `kInvoicePaymentPattern` casa com `foldText(line.description)`.
Linhas iguais dentro do mesmo arquivo **não** são marcadas entre si (dois cafés no mesmo dia são legítimos).
Custo: O(T) para montar + O(tamanho do balde) por linha. Diferença de dias calculada com `DateTime.utc` (sem horário de verão).

### 5.16 Sessão de prévia e plano de importação — `features/importing/domain/import_session.dart` (Fase 8)
```dart
class ImportTarget { const ImportTarget({this.accountId, this.cardId}); final String? accountId, cardId; } // exatamente um
class ImportRow {
  final ImportedLine line;
  final TransactionType type;          // expense (amount < 0) | income
  final bool include;
  final String finalDescription;       // renamedDescription da regra ?? line.description
  final String? categoryId;
  final CategorizationResult suggestion;
  final bool categoryEdited;           // usuário escolheu a categoria (recategorize não mexe)
  final ImportMatch match;
  final InstallmentMark? installment;
  final bool createInstallments;
  bool get confirmsPlanned => match.plannedMatch != null;
  bool get hasWarning => match.flags.isNotEmpty;
  ImportRow copyWith({bool? include, Object? categoryId = _keep, bool? categoryEdited, bool? createInstallments,
    String? finalDescription, CategorizationResult? suggestion});
}
class ImportSession {
  factory ImportSession.build({required List<ImportedLine> lines, required ImportTarget target, PaymentCard? card,
    required Categorizer categorizer, required ImportMatcher matcher, Map<String, String> bankCategoryMap = const {}});
  final List<ImportRow> rows;          // ordem do arquivo; imutável
  ImportSession setInclude(int i, bool value);
  ImportSession setAllIncluded(bool value);
  ImportSession setCategory(int i, String? categoryId);      // marca categoryEdited = true
  ImportSession setCreateInstallments(int i, bool value);    // ignorado se a linha não tem parcela
  ImportSession recategorize(Categorizer categorizer, {Map<String, String> bankCategoryMap = const {}});
    // linhas com categoryEdited == false recebem nova sugestão (categoria e finalDescription)
  List<int> uncategorizedIndices();    // categoryId == null (ordem)
  ({int create, int confirm, int skipped, int futureInstallments}) get summary;
}
class ImportPlan { const ImportPlan({required this.create, required this.update}); final List<Transaction> create, update; }
ImportPlan buildImportPlan(ImportSession session, {required ImportTarget target, PaymentCard? card,
  required DateTime today, InstallmentDateMode mode = InstallmentDateMode.posting, String Function() idGenerator = newId});
  // idGenerator: tear-off de core/utils/id.dart (testes injetam ids determinísticos)
Map<String, String> learnedBankCategories(ImportSession session);
  // linhas incluídas com line.bankCategory não vazia e categoryId != null → foldText(bankCategory) → categoryId (última vence)
```
**Build**, por linha: tipo pelo sinal; `installment = detectInstallment(line.description)`; `match = matcher.match(...)`;
`suggestion = categorizer.categorize(line.description, isIncome: tipo == income, bankCategory:, bankCategoryMap:)`;
`categoryId = plannedMatch?.categoryId ?? suggestion.categoryId`.
`include` padrão = **false** se `flags` contém `fitidDuplicate`, `probableDuplicate`, `existingInstallment` ou `invoicePaymentLike`; senão true
(`sameNameAmount` continua marcada: só pede confirmação). `createInstallments` padrão = `installment != null && installment.index < installment.count
&& !flags.contains(existingInstallment) && plannedMatch == null`.
`summary`: `create` = incluídas sem `plannedMatch`; `confirm` = incluídas com `plannedMatch`; `skipped` = não incluídas;
`futureInstallments` = soma de `count − index` das incluídas com `createInstallments`.

**Plano**, por linha incluída (linhas não incluídas não geram nada):
- `plannedMatch != null` → `update`: `plannedMatch.copyWith(status: paid, date: line.date, externalId: line.fitid ?? plannedMatch.externalId,
  importedDescription: line.description, categoryId: plannedMatch.categoryId ?? row.categoryId)` (descrição e valor do provisionado ficam).
- Senão, base: `Transaction(id: idGenerator(), type, amountCents: abs, date: line.date, description: finalDescription, categoryId,
  accountId/cardId do target, status: line.date > today ? planned : paid, externalId: line.fitid, importedDescription: line.description)`.
- Com `installment` e `createInstallments`: `groupId = idGenerator()`; para cada `(i, d)` de `importedInstallmentDates(lineDate: line.date,
  index, count, mode, card)`: id `'${groupId}_$i'`, data `d`, `installmentGroupId/Index/Count` preenchidos, valor = o da linha (cada parcela);
  `i == index` é a linha importada (status pela regra acima, com `externalId`); `i > index` → `status: planned`, `externalId: null`.
- Com `installment` e `!createInstallments` → transação simples (sem campos de parcela).
Gravação (camada de app): `transactions.upsertAll([...plan.create, ...plan.update])` — **um** notify.
Desempenho (teste obrigatório): 2.000 linhas contra 10.000 transações existentes → `ImportSession.build` + `buildImportPlan` < 2 s em `flutter test`.

### 5.17 Busca de transações — `features/transactions/domain/transaction_search.dart` (Fase 9)
Usada pela paleta de comandos (Ctrl+K). Dart puro, sobre `core/utils/fuzzy.dart` e `parseMoney`.
```dart
class TransactionSearchIndex {
  TransactionSearchIndex(Iterable<Transaction> transactions);
    // dobra UMA vez por transação: foldText(description) + foldedWords, e foldText(importedDescription) + words se não nulo
  List<Transaction> search(String query, {int limit = 20});
}
```
Regras de `search`:
1. `q = foldText(query)`; `q.length < 2` → `[]`. Tokens = `q.split(' ')` sem vazios.
2. Token **de valor**: começa com dígito e `parseMoney(token) != null` → `cents = parseMoney(token)!.abs()`.
3. Por transação e por token: `score = max(fuzzyTokenScore(token, descrição), fuzzyTokenScore(token, importedDescription),
   4 se o token é de valor e cents == t.amountCents)` (nulos ignorados). Algum token sem score → transação fora. Total = soma.
4. Ordena por total desc, `date` desc, `id` asc; `take(limit)`.
Exemplos (teste obrigatório; t1 `'UBER *TRIP'` 2315 05/11/2026; t2 `'Uber Eats'` 4590 10/11; t3 `'Padaria Pão Bom'` 1250 08/11 com
`importedDescription 'PADARIA PAO BOM CURITIBA PR'`; t4 `'Mercado Exemplo'` 2315 01/11; t5 `'Netflix'` 5990 03/11):
`search('uber') == [t2, t1]`; `search('23,15') == [t1, t4]`; `search('uber 23,15') == [t1]`; `search('curitiba') == [t3]`;
`search('pao') == [t3]`; `search('u') == []`; `search('xyz') == []`; 30 transações `'LOJA n'` → `search('loja').length == 20`.
Desempenho (teste obrigatório): 10.000 transações → construir o índice + 50 buscas < 1 s em `flutter test`.

### 5.18 Operações em massa e edição inline — `features/transactions/domain/transaction_bulk.dart` (Fase 9)
Regras financeiras das ações da multi-seleção e das células editáveis (Ultra). Dart puro; a UI só grava o resultado.
```dart
typedef BulkResult = ({List<Transaction> changed, int skipped});
BulkResult bulkRecategorize(Iterable<Transaction> selected, TransactionCategory? category);
  // Só expense/income. category null = limpar categoria. category.kind income → só income; expense → só expense.
  // transfer/invoicePayment e kind incompatível → skipped. Já iguais: nem changed nem skipped. changed na ordem de entrada.
BulkResult bulkConfirmPlanned(Iterable<Transaction> selected, DateTime paidOn);
  // t.isPlanned → t.copyWith(status: paid, date: dateOnly(paidOn)); demais → skipped. Mesma regra de "Confirmar provisionado" (§6.3), uma data para todos.
Set<String> installmentGroupsOf(Iterable<Transaction> selected); // installmentGroupId não nulos
Set<String> bulkDeleteIds(Iterable<Transaction> selected, Iterable<Transaction> all, {required bool wholeGroups});
  // ids dos selecionados; wholeGroups → + ids de `all` com installmentGroupId ∈ installmentGroupsOf(selected)
String? commonCategoryId(Iterable<Transaction> selected); // todas com a mesma categoria não nula → ela; senão (ou vazio) null
bool canEditCategoryInline(Transaction t); // expense ou income
bool canEditAmountInline(Transaction t);   // !t.isInstallment
int? parseInlineAmount(String input);      // parseMoney(input); null ou <= 0 → null (amountCents é sempre > 0)
```
Decisões de domínio:
- **Valor de parcela não é editável inline.** O formulário já edita uma parcela isolada, com o aviso de grupo; inline mudaria uma parcela sem
  o usuário ver o grupo. A célula de valor de parcela fica estática.
- Edição inline de valor também fica desligada com `hideValues` (o campo revelaria o valor).
- Excluir em massa respeita a regra de parcela (§6.3): se a seleção tem parcelas, o usuário escolhe "só as selecionadas" ou "grupos inteiros".
  Recorrência materializada apagada não volta (já garantido por `materializedUntil`, §4.5).
- Toda ação em massa grava com **um** `upsertAll` ou **um** `deleteWhere` (um notify).
Exemplos (teste obrigatório; categorias `cat_mercado` expense e `cat_salario` income; a despesa sem categoria; b despesa `cat_mercado`;
c receita sem categoria; d transferência; e/f despesas `planned` em conta; g/h/i parcelas 1/3, 2/3, 3/3 do grupo `g1`):
`bulkRecategorize([a, b, c, d], cat_mercado)` → changed `[a']` (com `cat_mercado`), skipped 2; `bulkRecategorize([a, b, c], null)` → changed `[b']`
sem categoria, skipped 0; `bulkRecategorize([c], cat_salario)` → changed `[c']`; `bulkConfirmPlanned([a, e, f], DateTime(2026, 11, 14, 15, 30))`
→ e/f `paid` em 14/11/2026, skipped 1; `installmentGroupsOf([a, g]) == {'g1'}`; `bulkDeleteIds([a, g], todas, wholeGroups: false) == {a, g}`,
com `true` → `{a, g, h, i}`; `canEditAmountInline(g) == false`; `canEditCategoryInline(d) == false`; `parseInlineAmount('12,50') == 1250`,
`('1.234,56') == 123456`, `('R$ 10') == 1000`, `('0')`, `('-5')`, `('abc')` → `null`.

### 5.19 Padrão de regra a partir da seleção — `features/rules/domain/rule_suggestion.dart` (Fase 9)
```dart
String suggestRulePattern(Iterable<String> subjects); // subjects = ruleSubject(t) das transações selecionadas
```
1. Para cada assunto: `f = foldText(s)`; tokens por `' '`; mantém os tokens até o primeiro que contém dígito ou é `PARC`/`PARCELA`/`PARCELADO`;
   `k = join(' ')`; `k` vazio → `k = f`.
2. `p` = maior prefixo comum (por caractere) de todos os `k`.
3. Se algum `k` é mais longo que `p`, `p` termina em `[A-Z0-9]` e esse `k[p.length]` também é `[A-Z0-9]` (corte no meio de palavra) →
   remove a sequência final de `[A-Z0-9]` de `p`.
4. Remove do fim todo caractere fora de `[A-Z0-9]`; `trim`. Lista vazia → `''`.
Invariante: resultado não vazio é prefixo de `foldText(s)` de **todos** os assuntos → regra `contains` (padrão do form) casa com toda a seleção.
Exemplos (teste obrigatório): `['UBER *TRIP 8X7Y2 SAO PAULO BR']` → `'UBER *TRIP'`; `['UBER *TRIP 8X7Y2', 'UBER *EATS 123']` → `'UBER'`;
`['IFOOD*RESTAURANTE X', 'IFOOD*PADARIA']` → `'IFOOD'`; `['LOJA EXEMPLO PARC 03/10', 'LOJA EXEMPLO PARC 04/10']` → `'LOJA EXEMPLO'`;
`['MERCADO A', 'MERCADINHO B']` → `''`; `['Farmácia São João 0412']` → `'FARMACIA SAO JOAO'`; `['PADARIA PAO', 'PADARIA PAO BOM']` →
`'PADARIA PAO'`; `['123456']` → `'123456'`; `[]` → `''`.

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
  // Fase 8 (obrigatórios no construtor; só o bootstrap constrói AppServices):
  final CollectionRepository<TransactionRule> rules;
  final CollectionRepository<ImportProfile> importProfiles;
  final CollectionRepository<DictionaryEntry> dictionary;
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
  static const int invoiceTimelineDays = 60;
  Forecast get forecast;                      // months: settings.forecastMonths, minDays: invoiceTimelineDays
  Map<String?, int> spendingFor(YearMonth m);
  List<Transaction> upcoming({int days = 30}); // planned + ocorrências projetadas no período, ordenado
  // Fase 5 (memoizados como os demais):
  List<InvoiceDue> get invoiceTimeline;            // invoiceTimeline(forecast, faturas de todos os cartões de crédito, days: 60)
  List<CardPurchaseOption> get bestCardsToday;     // bestCardsToBuy(cards.all, {id: usedLimitFor(id)}, today)
  List<InstallmentCommitment> get installmentCommitments; // from: mês atual.next(), months: 12
  List<PaymentCard> get cardsWithoutPaymentAccount; // ids ativos = contas !archived
  // Fase 7 (memoizados como os demais):
  List<MonthSnapshot> get monthlyHistory;          // monthlyHistory(..., today: today, months: 6)
  ({int current, int previous}) get expenseMonthToDate;
    // current = monthlyHistory.last.expenseCents; previous = expenseUntilDay(transactions, mês anterior, today.day)
  // Fase 8:
  Ledger({..., CollectionRepository<TransactionRule>? rules, CollectionRepository<DictionaryEntry>? dictionary});
    // opcionais (testes que constroem Ledger direto seguem válidos); null = lista vazia; quando presentes entram em _sources
  Categorizer get categorizer;
    // Categorizer(rules: rules?.all ?? [], categories: categories.all,
    //   history: CategoryHistory.build(transactions.all), dictionary: dictionary?.all ?? []) — memoizado
}
```
Cada getter é preguiçoso e memoizado; o cache inteiro é invalidado quando qualquer repo/settings notifica
**ou quando `today` muda** (virada de dia: invalida, roda `materializeRecurring` e notifica).
`upcoming` lista só **saídas** (despesas/boletos provisionados e projetados de conta).

### 6.3 Ações de escrita (em `features/*/presentation/*_actions.dart` ou no próprio form)
- Salvar compra parcelada: `buildInstallments` e `transactions.upsertAll`.
- Excluir parcela: perguntar "só esta" / "todas do grupo" (`deleteWhere` por `installmentGroupId`).
- Pagar fatura: cria `Transaction(type: invoicePayment, accountId, cardId, invoiceKey, amount = remaining (editável), date = hoje, status: paid)`.
- Confirmar provisionado: `status → paid` (data editável).
- Excluir conta/cartão com transações: só arquivar (`archived = true`).
- Importar (Fase 8, `features/importing/presentation/import_flow.dart`): monta `ImportSession` com `ledger.categorizer` e
  `ImportMatcher(transactions.all)`, abre a prévia e grava o `ImportPlan` com **um** `transactions.upsertAll`. Se o perfil é salvo,
  `importProfiles.upsert(profile.learnBankCategories(learnedBankCategories(session)))`.
- Reaplicar regras (Fase 8): `transactions.upsertAll(reapplyRules(compileRules(rules.all), transactions.all, categoriesById: ..., overwriteCategory: ...))`.
- Reordenar regras: `rules.upsertAll(reorderRules(novaOrdem))`.
- Ações em massa (Fase 9, `transactions_page.dart`, sobre a seleção visível — §5.18):
  recategorizar → `transactions.upsertAll(bulkRecategorize(sel, cat).changed)`;
  confirmar pagamento → `transactions.upsertAll(bulkConfirmPlanned(sel, data).changed)`;
  excluir → `ids = bulkDeleteIds(sel, transactions.all, wholeGroups: ...)`; `transactions.deleteWhere((t) => ids.contains(t.id))`;
  criar regra → `showRuleForm(context, initialPattern: suggestRulePattern(sel.map(ruleSubject)), initialCategoryId: commonCategoryId(sel),
  sampleDescription: ruleSubject(sel.first))`; regra devolvida → `transactions.upsertAll(reapplyRules(compileRules([regra]), sel,
  categoriesById: ledger.categoriesById, overwriteCategory: true))` (a seleção passa a seguir a regra na hora).
- Edição inline (Fase 9): categoria → `transactions.upsert(t.copyWith(categoryId: v))`; valor → `transactions.upsert(t.copyWith(amountCents: v))`
  com `v = parseInlineAmount(texto)` e só se `canEditAmountInline(t)` e `!hideValues`.

## 7. UI

Visual conforme `CLAUDE.md` (paleta, tipografia, espaçamento) e `docs/V3_DIRECTION.md`. Tom: sóbrio, entre sério e wabi-sabi. Cores via `context.colors` (extensão em `core/theme/app_colors.dart`).

### 7.1 Tema — `lib/core/theme/`
- `app_colors.dart`: `class AppColors extends ThemeExtension<AppColors>` com tokens `background, surface, sidebar, primary, primarySubtle, textPrimary, textSecondary, chartBar, warning, danger, success, border` + `AppColors.light`/`AppColors.dark` (valores do CLAUDE.md; `success` = `#43A047`/`#66BB6A`; `border` = textSecondary α 0.15) + `extension AppColorsX on BuildContext { AppColors get colors; }`.
  Neutros quentes (Fase 7): claro `background #F6F5F2`, `surface #FFFFFF`, `sidebar #ECEAE5`; escuro `background #161514`, `surface #1F1E1C`, `sidebar #2A2826`. Primário, status e texto inalterados.
- `app_spacing.dart`: `AppSpace.xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`; `AppRadius.card=8, chip=4` (+ `BorderRadius` prontos);
  `abstract final class AppMotion { static const fast = Duration(milliseconds: 150); static const normal = Duration(milliseconds: 200); static const curve = Curves.easeOutCubic; }` (Fase 7). Toda microanimação usa esses valores.
- `app_palettes.dart`: `const List<int> kEntityColors` (10 cores ARGB para contas/cartões/categorias) e `const List<int> kCategoryIcons` (codepoints de `Icons.*` comuns — use `Icons.x.codePoint`). Única exceção permitida a valores fixos.
- `app_text.dart` (Fase 7):
  ```dart
  abstract final class AppFonts { static const sans = 'IBMPlexSans'; static const serif = 'SourceSerif4'; }
  abstract final class AppText {
    static const tabularFigures = [FontFeature.tabularFigures()];
    static TextStyle tabular(TextStyle style);           // style.copyWith(fontFeatures: tabularFigures)
    static TextStyle screenTitle(BuildContext context);  // textTheme.titleLarge (serif, 20, w600)
    static TextStyle kpi(BuildContext context);          // serif, 22, w600, textPrimary, tabular
  }
  ```
- `app_theme.dart`: `ThemeData AppTheme.light()` / `AppTheme.dark()` — Material 3, `fontFamily: AppFonts.sans`, `extensions: [AppColors.x]`, `scaffoldBackgroundColor`, `cardTheme` (radius 8, elevation 0, borda), `inputDecorationTheme` (outline, dense), `dividerTheme`, `textTheme` (títulos 20 w600 **serif** em `titleLarge`; seções 14 w600, corpo 13, apoio 12, badge 11 em sans), `tooltipTheme` (fundo `surface`, borda `border`, texto `textPrimary` 12, radius 4, `waitDuration` 300 ms).
- Fontes (Fase 7): `assets/fonts/` com IBM Plex Sans (Regular 400, Medium 500, SemiBold 600) e Source Serif 4 (Regular 400, Semibold 600), licença OFL (`OFL-*.txt` no mesmo diretório). Declaradas em `pubspec.yaml` (`flutter: fonts:`), famílias `IBMPlexSans` e `SourceSerif4`. Não é dependência nova (asset).

### 7.2 Widgets compartilhados — `lib/core/widgets/`
`MoneyText(int cents, {style, signed, colorBySign})` (respeita `hideValues`; algarismos tabulares), `SectionCard(title, trailing, child)`,
`EmptyState(icon, message, action?)`, `LimitBar(used, limit)` (cor muda: <70% primary, <90% warning, ≥90% danger; Fase 7: `Tooltip` "Usado R$ X de R$ Y (Z%)"),
`StatusBadge(label, color)`, `MonthSelector(value, onChanged)`, `MoneyField(controller, label)`,
`DateField(value, onChanged, label)`, `confirmDialog(context, title, message) → Future<bool>`,
`PlannedMarker` (ícone relógio + itálico para provisionados), `KpiTile(label, cents, color?, caption?, trend?)` (valor em `AppText.kpi`; Fase 7: `Widget? trend` abaixo do valor; troca de valor com `AnimatedSwitcher` fade `AppMotion.fast`).

Fase 7 (arquivos novos, exportados por `widgets.dart`):
- `trend.dart`: `DeltaBadge({required double? ratio, bool higherIsBetter = true})` → "▲ 12,3%" / "▼ 5,0%" (11 px w500, tabular); cor `success` se a variação é boa, `danger` se ruim, `textSecondary` se `ratio == 0`; `ratio == null` → `SizedBox.shrink()`. `Tooltip` "vs. mês anterior".
  `Sparkline({required List<int> values, double width = 80, double height = 24, Color? color})` → `LineChart` do fl_chart sem eixos, grade, borda, pontos e toque; `color ?? colors.primary`; menos de 2 valores → `SizedBox(width, height)`.
- `bank_avatar.dart`: `BankAvatar({required String bankName, double size = 24})` → quadrado `AppRadius.chip` com fundo `Color(kEntityColors[bankColorIndex(name)])` α 0.18 e iniciais na cor cheia (11 px w600). Nome vazio → "?" com `textSecondary`. Funções públicas puras: `String bankInitials(String name)` (trim; 2+ palavras → 1ª letra das 2 primeiras; 1 palavra → 2 primeiras letras; maiúsculas; vazio → "?") e `int bankColorIndex(String name)` (hash estável: `h = (h * 31 + codeUnit) & 0x7fffffff` sobre `name.trim().toLowerCase()`, `% kEntityColors.length`). Nunca logo real.
- `skeleton.dart`: `SkeletonBox({double? width, required double height})` (retângulo `textSecondary` α 0.12, `AppRadius.chip`) e `SkeletonPulse({required Widget child})` (opacidade 0.5↔1.0 em loop de 900 ms). `SkeletonList({int rows = 6})` = coluna de `SkeletonBox` dentro de um `SkeletonPulse`.
- `sortable_header.dart`: `SortableHeaderLabel({required String label, required bool active, required bool ascending, required VoidCallback? onTap, bool alignEnd = false})` → texto do cabeçalho (12 px w600 `textSecondary`; ativo → `textPrimary`) + seta `Icons.arrow_upward` 14 px visível só se `active`, girada 180° quando `!ascending` (`AnimatedRotation` `AppMotion.fast`). `onTap == null` → não clicável.

### 7.3 Shell e telas
`HomeShell`: só desktop, sempre com sidebar (`colors.sidebar`). Largura ≥ 900 → sidebar 220px com itens ícone+rótulo, item ativo com `primarySubtle`, rodapé com toggle "Modo: Simples/Ultra"; Ultra mostra badge de contagem (faturas vencidas/pendências). < 900 → sidebar colapsada de 64px só com ícones (rótulo em `Tooltip`; badge vira ponto `danger` 8px; rodapé vira `IconButton` de modo com tooltip "Modo: Simples/Ultra"). Largura animada com `AnimatedContainer` (`AppMotion.normal`). Sem `Drawer` nem `AppBar`.
Páginas (índice): 0 Painel, 1 Previsão, 2 Cartões, 3 Contas, 4 Transações, 5 Importar (Fase 8), 6 Recorrentes, 7 Categorias, 8 Ajustes.
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

#### Previsibilidade avançada (Fase 5)
| Recurso | Onde | Simples | Ultra |
|---|---|---|---|
| Cobertura de faturas (§5.9 `needsAttention`) | Painel | 1 banner (cor `danger`): "N faturas nos próximos 60 dias sem saldo previsto na conta de pagamento" + a mais próxima (cartão, data). Oculto se N = 0 | `SectionCard` "Cobertura de faturas": linha por fatura com data, cartão, conta (ou "Sem conta de pagamento" em `warning`), valor, saldo após (`danger`) |
| Linha do tempo de vencimentos (60 dias) | Previsão | — | `SectionCard` "Vencimentos (60 dias)": agrupado por dia; linha = cartão, conta, valor, saldo previsto da conta após; badge "Vencida" (overdue), saldo < 0 em `danger` |
| Compromisso de parcelas M+1..M+12 | Previsão | — | `SectionCard` "Parcelas já comprometidas": tabela meses × (Total + 1 coluna por cartão com algum valor), rolagem horizontal |
| Melhor cartão para comprar hoje (§5.8) | Cartões (topo) | 1 linha: "Melhor para comprar hoje: {cartão} — fatura vence em N dias ({dd/mm})" (1º com `hasLimit`; oculto se nenhum) | `SectionCard` com tabela: cartão, banco, vencimento, dias, limite livre (`danger` se ≤ 0) |
| Cartão sem conta de pagamento | Cartões (`CardTile`) | badge `warning` "Sem conta de pagamento" | idem |
| Mudança de ciclo com vigência (§4.2) | Form de cartão | ao editar fechamento/vencimento de cartão de crédito **com transações**, pergunta "Vale a partir de" (padrão hoje) e salva via `withCycleChange` | idem |

#### Identidade visual e polimento (Fase 7)
| Recurso | Onde | Simples | Ultra |
|---|---|---|---|
| Fontes e paleta quente (§7.1) | App inteiro | sim | sim |
| Delta vs. mês anterior + sparkline 6 meses (§5.10) | Painel, KPI "Saldo atual": delta `deltaRatio(history[n-2].endBalanceCents, history.last.endBalanceCents)`, `higherIsBetter: true`; sparkline = `endBalanceCents` | — | sim |
| KPI "Gasto no mês" | Painel (5º KPI): valor `expenseMonthToDate.current`, caption "até hoje"; delta `deltaRatio(previous, current)` com `higherIsBetter: false`; sparkline = `expenseCents` dos 6 meses | — | sim |
| Avatar de banco | Cabeçalho de banco em Cartões e Contas | — | sim |
| Cabeçalho ordenável (fixo) | Transações: Data, Descrição, Conta/Cartão, Categoria, Valor; clique alterna asc/desc; padrão Data desc | — (cabeçalho estático) | sim |
| Estado vazio com ação | Transações ("Nova transação"; Ultra com filtro ativo: "Limpar filtros"), Recorrentes ("Nova recorrência"), Categorias ("Nova categoria") | sim | sim |
| Tooltip rico | Gráfico de saldo diário (data, saldo, entradas e saídas do dia, nº de eventos); `LimitBar` | — (gráfico só Ultra) | sim |
| Skeleton de boot | `main.dart` mostra `BootScreen` enquanto `bootstrap()` roda | sim | sim |
| Microanimações 150–200 ms | Sidebar (item ativo e colapso), seta de ordenação, troca de valor do KPI | sim | sim |

Dados de delta/sparkline vêm de `Ledger.monthlyHistory` / `Ledger.expenseMonthToDate` (memoizados), nunca calculados em `build`.

#### Importação, regras e categorização (Fase 8)
Decisões de navegação: **Importar** é item da sidebar (índice 5, `Icons.upload_file`, nos dois modos) e botão "Importar" no cabeçalho
de Transações (abre o fluxo direto). **Regras** e **Dicionário** são seções da página Importar, visíveis só no Ultra
(no Simples a página mostra só "Importar arquivo" e os perfis). Total de 9 páginas: cabe nos atalhos 1–9 da Fase 9.
Arquivos em `features/importing/presentation/` (`import_page.dart`, `import_flow.dart`, `import_mapping_dialog.dart`,
`import_preview_page.dart`, `import_preview_row.dart`, `dictionary_section.dart`) e `features/rules/presentation/`
(`rules_section.dart`, `rule_form.dart`).

| Recurso | Onde | Simples | Ultra |
|---|---|---|---|
| Página Importar | sidebar índice 5 | `PageHeader('Importar')` + botão "Importar arquivo"; `SectionCard` "Perfis salvos" (nome, destino com `BankAvatar` só no Ultra, formato, botões "Importar" (1 clique), editar, excluir); `EmptyState` com ação "Importar arquivo" | + `SectionCard` "Regras" e `SectionCard` "Dicionário de estabelecimentos" |
| Fluxo | `startImport(context, {profile, pickFile})` | arquivo (`file_selector`, `.csv/.ofx/.txt`) → CSV: assistente de mapeamento; OFX: diálogo de destino → prévia → grava | idem |
| Assistente CSV | `showImportMappingDialog` | separador, linhas a pular, amostra (8 linhas, cabeçalho = linha `skipRows−1`), colunas data/descrição/valor ou débito+crédito/categoria, formato de data, decimal, inverter sinal, data das parcelas, destino, "Salvar como perfil" + nome; prévia de 5 linhas interpretadas (ou erro) | idem |
| Prévia | `showImportPreview` (tela cheia) | colunas: incluir, data, descrição final, valor (`MoneyText` com sinal), categoria (dropdown), 1 ícone de alerta com tooltip; rodapé com resumo e "Importar N" | + descrição original → final, origem da sugestão (Regra/Banco/Histórico/Dicionário) + confiança (alta/média/baixa), ícones por flag, chip de parcela "3/10" com checkbox "criar futuras", filtro "Só sem categoria", marcar/desmarcar todas, menu "Criar regra a partir desta linha" |
| Regras | seção da página Importar | — | lista reordenável (arrastar = prioridade), switch ativa, padrão, tipo, → categoria, renomear; "Nova regra"; "Reaplicar às transações" com prévia "N transações mudam (X categoria, Y descrição)" e opção "Sobrescrever categorias já definidas" |
| Form de regra | `showRuleForm` | — | padrão, tipo (Contém/Começa com/Regex), categoria, renomear para, ativa; botão "Testar padrão" (contagem + até 5 descrições existentes que casam; com `sampleDescription`, mostra se casa com a linha) |
| Dicionário | seção da página Importar | — | lista densa padrão → categoria (badge `warning` "Categoria não encontrada" se não resolve), novo/editar/excluir, "Restaurar padrão" (confirmação) |
| Sugestão no lançamento manual | `transaction_form.dart` | ao digitar a descrição de nova despesa/receita, se o usuário ainda não escolheu categoria, aplica `ledger.categorizer` e mostra `helperText` "Sugerida por regra" / "Sugerida pelo banco" / "Sugerida pelo histórico" / "Sugerida pelo dicionário" | idem |

Visual da prévia (segue a Fase 7): linhas com `itemExtent` (40 Ultra, 48 Simples) em `ListView.builder`; cabeçalho com
`SortableHeaderLabel(onTap: null)` (estático); valores tabulares; ícones de flag: `fitidDuplicate`/`probableDuplicate`
`Icons.content_copy` (`danger`/`warning`), `existingInstallment` `Icons.layers` (`warning`), `sameNameAmount` `Icons.repeat`
(`textSecondary`), `invoicePaymentLike` `Icons.credit_score` (`warning`), casamento com provisionado `Icons.event_available` (`primary`)
com tooltip "Confirma provisionado {descrição} de {dd/mm}". Linha desmarcada: texto `textSecondary`. Ultra rola na horizontal
abaixo de 1100 px. Sem cálculo em `build`: a sessão já traz tudo; filtros só selecionam índices.

#### Produtividade (Fase 9)
Sem dependência nova: `Shortcuts`/`Actions`/`CallbackShortcuts`/`Focus` do Flutter. Lógica testável fora da UI: ranking (§3.8, §5.17),
operações em massa (§5.18), padrão de regra (§5.19) e seleção (`TransactionSelection`, abaixo).

| Recurso | Simples | Ultra |
|---|---|---|
| Paleta Ctrl+K (navegar, ações, buscar transações) | sim (busca ignora provisionados de conta, como a tabela) | sim + entrada "Filtrar Transações do mês por “q”" |
| Atalhos globais (N, /, 1–9, Ctrl+K, Ctrl+I) | sim (`/` sempre abre a paleta) | sim (`/` foca a busca da página Transações quando ela está aberta) |
| Dicas de atalho (tooltips, rodapé da paleta, entrada "Buscar" na sidebar) | sim | sim |
| Multi-seleção, Ctrl+A, Esc, barra de ações em massa | — | sim |
| Edição inline de categoria e valor | — | sim |

**Atalhos** (`lib/app/app_shortcuts.dart`):
```dart
class OpenPaletteIntent extends Intent { const OpenPaletteIntent(); }
class NewTransactionIntent extends Intent { const NewTransactionIntent(); }
class FocusSearchIntent extends Intent { const FocusSearchIntent(); }
class ImportFileIntent extends Intent { const ImportFileIntent(); }
class GoToPageIntent extends Intent { const GoToPageIntent(this.index); final int index; } // 0..8
class SelectAllRowsIntent extends Intent { const SelectAllRowsIntent(); }
class ClearSelectionIntent extends Intent { const ClearSelectionIntent(); }
final Map<ShortcutActivator, Intent> kAppShortcuts;
  // SingleActivator(keyK, control: true) → OpenPaletteIntent; SingleActivator(keyI, control: true) → ImportFileIntent;
  // SingleActivator(keyN) → NewTransactionIntent; CharacterActivator('/') → FocusSearchIntent (independe do layout ABNT2/US);
  // SingleActivator(digit1..digit9) e SingleActivator(numpad1..numpad9) → GoToPageIntent(0..8)
final Map<ShortcutActivator, Intent> kSelectionShortcuts;
  // SingleActivator(keyA, control: true) → SelectAllRowsIntent; SingleActivator(escape) → ClearSelectionIntent
bool isTextInputFocused();
  // FocusManager.instance.primaryFocus?.context: widget é EditableText ou tem EditableTextState acima
class TypingGuardAction<T extends Intent> extends CallbackAction<T> {
  TypingGuardAction({required super.onInvoke});
  @override bool isEnabled(T intent) => !isTextInputFocused(); // desabilitada → evento segue (campo recebe a tecla)
}
```
Regras: atalhos sem modificador (N, /, 1–9) e os de seleção (Ctrl+A, Esc) usam `TypingGuardAction` — **não disparam com foco em campo de texto**
(Ctrl+A no campo seleciona o texto). Ctrl+K e Ctrl+I usam `CallbackAction` (valem também com foco em campo). Diálogos e rotas por cima do shell
não recebem os atalhos (não são descendentes do shell).

**Foco do shell**: `HomeShell` = `Shortcuts(kAppShortcuts)` > `Actions` > `Focus(focusNode: _shellFocus, autofocus: true)` > `Scaffold`.
O shell guarda `_txFocus` e `_txSearchFocus` (`FocusNode`) e passa para `TransactionsPage`. Ao trocar de página e quando o foco primário cai num
`FocusScopeNode` (nenhum nó folha focado) com a rota do shell no topo, o shell pede foco (pós-frame) em `_txFocus` se a página é Transações, senão
em `_shellFocus`. Ações: N → `showTransactionForm(context)`; Ctrl+I → `startImport(context)`; 1–9 → página `i`; Ctrl+K → paleta;
`/` → Ultra e página 4: `_txSearchFocus.requestFocus()`; senão abre a paleta. Paleta aberta não reabre (flag `_paletteOpen`).

**Paleta** (`lib/app/command_palette.dart`):
```dart
class PaletteEntry {
  const PaletteEntry({required this.label, required this.icon, required this.onRun, this.subtitle, this.shortcut,
    this.keywords = const [], this.trailing, this.group = 'Comandos'});
  final String label; final IconData icon; final VoidCallback onRun;
  final String? subtitle; final String? shortcut; final List<String> keywords; final Widget? trailing; final String group;
}
Future<void> showCommandPalette(BuildContext context, {required List<PaletteEntry> commands,
  List<PaletteEntry> Function(String query)? search});
  // resultados = fuzzyRank(commands, q, (e) => [e.label, ...e.keywords], limit: 8) seguidos de search?.call(q) (já ordenados).
  // Fecha com pop(entry) e SÓ DEPOIS chama entry.onRun() (o comando roda no contexto de quem abriu).
```
Visual: `Dialog` no topo (`alignment: Alignment.topCenter`, `insetPadding` topo 80), largura máx. 640, altura máx. 480, raio `AppRadius.card`.
Campo com `Icons.search`, hint 'Buscar comandos e transações', `autofocus`. Lista com `itemExtent` 44; cabeçalho de grupo (12 px w600 `textSecondary`)
quando `group` muda; linha = ícone 18, `label` (13), `subtitle` (12 `textSecondary`), à direita `trailing` e/ou `shortcut` em chip (11 px w500,
borda `border`, raio `AppRadius.chip`). Item destacado com `primarySubtle`. Vazio → 'Nada encontrado'. Rodapé (12 `textSecondary`):
'↑↓ navegar · Enter executar · Esc fechar'. Teclado: `CallbackShortcuts` em volta do campo (mais perto do foco que os atalhos de texto):
↓/↑ movem o destaque (limitado às pontas, sem volta) e rolam para mantê-lo visível; Enter executa o destacado (`onSubmitted`); Esc fecha
(padrão do `Dialog`). Clique executa. Mudar o texto zera o destaque em 0. Keys: `palette-input`, `palette-item-$i`.

**Comandos** (`lib/app/app_commands.dart`), na ordem: 'Ir para {página}' ×9 (ícones de `_navItems`, `shortcut` '1'..'9', keywords [nome da página]),
'Nova transação' (N; keywords: lançar, despesa, receita, adicionar), 'Importar arquivo' (Ctrl+I; csv, ofx, extrato), 'Nova recorrência'
(assinatura, fixo), 'Mudar para Modo Ultra' / 'Mudar para Modo Simples' (modo), 'Alternar tema claro/escuro' (tema, escuro, claro),
'Ocultar valores' / 'Mostrar valores' (privacidade, esconder). Tema: `brightness` atual escuro → `ThemePreference.light`, senão `dark`.
Busca (query com 2+ caracteres): Ultra põe primeiro `PaletteEntry(group: 'Transações', label: 'Filtrar Transações do mês por “q”', icon: Icons.filter_list)`
→ vai para a página 4 com `initialQuery: q`; depois até 20 transações de `TransactionSearchIndex.search` (índice construído uma vez ao abrir a
paleta; Simples exclui `isProvisioned`): label = descrição (+ ' i/n' se parcela), subtitle = 'dd/mm/aaaa · conta/cartão · categoria',
`trailing` = `MoneyText` com sinal (respeita `hideValues`), `onRun` → `showTransactionForm(context, initial: t)`.

**Seleção** (`features/transactions/presentation/transaction_selection.dart`, Dart puro, imutável):
```dart
class TransactionSelection {
  const TransactionSelection({this.ids = const {}, this.anchorId});
  static const empty = TransactionSelection();
  final Set<String> ids; final String? anchorId;
  bool contains(String id);
  TransactionSelection toggle(String id);                       // inverte id; anchorId = id
  TransactionSelection extendTo(String id, List<String> order); // Shift+clique: anchor nulo/fora de order ou id fora → toggle(id);
                                                                // senão ids ∪ order[min(ia, ib)..max(ia, ib)]; anchorId mantido
  TransactionSelection selectAll(List<String> order);           // ids = order; anchorId mantido
  List<String> selectedIn(List<String> order);                  // interseção na ordem de order
  bool? allState(List<String> order);                           // order vazio ou nenhum → false; todos → true; parcial → null
}
```
**Transações Ultra com seleção**: coluna de checkbox à esquerda (`kTxSelectWidth = 36`; `kTxUltraMinWidth` passa a 796) nas linhas e no
cabeçalho (tristate por `allState`; clicar com tudo marcado limpa, senão marca todas as visíveis). Clique no checkbox → `toggle`; com Shift
(`HardwareKeyboard.instance.isShiftPressed`) → `extendTo`. Clique no resto da linha continua abrindo o formulário. Linha selecionada:
fundo `primarySubtle` (vence o fundo de provisionado). A página envolve o conteúdo em `Shortcuts(kSelectionShortcuts)` > `Actions` >
`Focus(focusNode: widget.focusNode ?? próprio, autofocus: true)`: Ctrl+A marca todas as linhas visíveis; Esc limpa. Ações valem para
`selectedIn(linhas visíveis)` (filtro escondeu → não entra). Trocar de mês limpa a seleção; Simples não mostra nem usa seleção.
**Barra de ações em massa** (`bulk_action_bar.dart`, só com seleção visível não vazia, entre filtros e tabela, altura 40, fundo
`primarySubtle`, raio `AppRadius.card`): '{N} selecionadas' + `BulkAction`s em ordem — 'Recategorizar' (`Icons.category_outlined`),
'Confirmar pagamento' (`Icons.event_available`; desabilitado se nenhuma `isPlanned`), 'Criar regra' (`Icons.rule`), 'Excluir'
(`Icons.delete_outline`, cor `danger`) — e `IconButton` `Icons.close` tooltip 'Limpar seleção (Esc)'.
```dart
class BulkAction { const BulkAction({required this.label, required this.icon, required this.onPressed, this.destructive = false});
  final String label; final IconData icon; final VoidCallback? onPressed; final bool destructive; } // null = desabilitado
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({super.key, required this.count, required this.actions, required this.onClear});
  final int count; final List<BulkAction> actions; final VoidCallback onClear; }
```
A lista de `BulkAction` é montada pela página: a Fase 10 acrescenta 'Tags' sem mudar a barra.
Diálogos (`bulk_dialogs.dart`; guarda contra duplo pop como os diálogos atuais):
```dart
typedef CategoryChoice = ({TransactionCategory? category}); // category null = 'Sem categoria'
Future<CategoryChoice?> showBulkCategoryDialog(BuildContext context, {required int count, required List<TransactionCategory> categories});
  // título 'Recategorizar {count}'; dropdown 'Sem categoria' + despesas (por nome) + receitas (por nome, sufixo ' (receita)'); null = cancelou
Future<DateTime?> showBulkConfirmDialog(BuildContext context, {required int count, required DateTime initialDate});
  // título 'Confirmar {count} provisionados'; DateField 'Data do pagamento'; botões 'Cancelar' / 'Confirmar'
enum BulkDeleteScope { selected, wholeGroups }
Future<BulkDeleteScope?> showBulkDeleteDialog(BuildContext context, {required int count, required int groups, required int wholeGroupsCount});
  // groups == 0: 'Excluir {count} transações?' com 'Cancelar' / 'Excluir' (danger) → selected.
  // groups > 0: texto '{groups} grupos de parcelas na seleção.'; 'Cancelar' / 'Só as {count} selecionadas' → selected /
  //   'Grupos inteiros ({wholeGroupsCount} lançamentos)' (danger) → wholeGroups
```
Depois de cada ação: SnackBar — recategorizar '{changed} recategorizadas' (+ ' · {skipped} ignoradas (tipo incompatível)' se > 0); confirmar
'{changed} provisionados confirmados'; excluir '{n} transações excluídas' e limpa a seleção; regra 'Regra criada · {n} transações atualizadas'.
Recategorizar e confirmar mantêm a seleção.

**Edição inline (Ultra)** (`inline_cells.dart`):
```dart
class InlineCategoryCell extends StatelessWidget {
  const InlineCategoryCell({super.key, required this.categoryId, required this.options, required this.onChanged});
  final String? categoryId; final List<TransactionCategory> options; final ValueChanged<String?> onChanged; }
  // DropdownButton<String?> isDense, isExpanded, sem sublinhado, 12 px textSecondary: 'Sem categoria' + options
class InlineAmountCell extends StatefulWidget {
  const InlineAmountCell({super.key, required this.display, required this.amountCents, required this.onSubmit});
  final Widget display; final int amountCents; final ValueChanged<int> onSubmit; }
  // Exibe `display` com Tooltip 'Clique para editar o valor'; clique (GestureDetector, vence o InkWell da linha) → TextField denso,
  // alinhado à direita, autofocus, texto formatMoney(amountCents) sem 'R$ ' todo selecionado, key 'inline-amount-field'.
  // Enter: v = parseInlineAmount(texto); v nulo → continua editando com borda danger; v == amountCents → só sai; senão onSubmit(v) e sai.
  // Esc (CallbackShortcuts no campo, não chega à seleção) ou perda de foco → cancela sem gravar.
```
`TransactionRow` (Ultra) ganha: `bool? selected` (null = sem checkbox), `VoidCallback? onToggleSelect`, `List<TransactionCategory>? categoryOptions`
+ `ValueChanged<String?>? onCategoryChanged` (os dois não nulos e `canEditCategoryInline` → `InlineCategoryCell`; senão texto), `ValueChanged<int>? onAmountChanged`
(não nulo → `InlineAmountCell`; senão `MoneyText`). Opções de categoria = categorias do `kind` do tipo, por nome. Keys: `tx-select-<id>`,
`inline-category-<id>`, `inline-amount-<id>`; cabeçalho `tx-select-all`.

**Dicas de atalho**: FAB `tooltip: 'Atalho: N'`; botão 'Nova transação' de Transações em `Tooltip('Atalho: N')`; botão 'Importar' em
`Tooltip('Atalho: Ctrl+I')`; sidebar larga: cada item em `Tooltip('Atalho: {i+1}')` e entrada 'Buscar' (ícone `Icons.search`, texto à direita
'Ctrl+K' 11 px `textSecondary`, key `sidebar-search`) abaixo do logo; sidebar colapsada: tooltip do item '{rótulo} · {i+1}' e `IconButton`
`Icons.search` tooltip 'Buscar (Ctrl+K)'. As duas entradas de busca abrem a paleta.

### 7.4 Onboarding
Uma tela: escolher modo (Simples/Ultra) + checkbox "Criar dados de exemplo" (fictícios: "Banco Alfa", "Banco Beta"; nunca bancos reais). Grava `onboardingDone`.

## 8. Testes
- Unitários obrigatórios para todo `domain/` e `core/utils|models|services`.
- `test/` espelha `lib/` (`test/features/cards/domain/invoice_cycle_test.dart`).
- Widget smoke test: app sobe com `MemoryRecordStore` e navega pelas 9 páginas (Fase 8) sem exceção (janela larga 1400×900 e estreita 800×700 com sidebar colapsada).
- Fixtures de importação (Fase 8): `test/fixtures/import/` com arquivos **fictícios** (texto exato no BACKLOG, T-074/T-075). Nunca dado real.
- Atalhos (Fase 9): testes de widget usam `tester.sendKeyEvent` / `sendKeyDownEvent(LogicalKeyboardKey.controlLeft)` e cobrem o caso
  "tecla com foco em campo de texto não dispara".
- Portão: `bash tool/check.sh` → `CHECK OK`.
