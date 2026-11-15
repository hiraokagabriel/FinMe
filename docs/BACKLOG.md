# FinMe v2 — Backlog

> Status: `todo` · `doing` · `done` · `blocked`. Contratos em `docs/SPEC.md` (seção indicada).
> Toda tarefa termina com `bash tool/check.sh` → `CHECK OK`.
> Workflow: skill `finme-auto` (`.claude/skills/finme-auto/SKILL.md`).

## Fase 0 — Fundação

### T-001 · Limpeza e base · `done`
Remove `lib/` e `test/` antigos, ajusta `pubspec.yaml`, `analysis_options.yaml` (exclui `FinMe/**`, `build/**`), cria `tool/check.sh`.

### T-002 · Utilitários core · `done` · deps: T-001 · parallel: yes
files: `lib/core/models/year_month.dart`, `lib/core/utils/date_utils.dart`, `lib/core/utils/formatters.dart`, `lib/core/utils/id.dart`, `test/core/year_month_test.dart`, `test/core/utils_test.dart`
contrato: SPEC §3.1–3.4
aceite: virada de ano (`2026-12 + 1 = 2027-01`, `2026-01 - 1 = 2025-12`), `dateAt(31)` em fev bissexto/não, `addMonthsClamped(31/01/2026, 1) = 28/02/2026`, `formatMoney(123456) = "R$ 1.234,56"`, `formatMoney(-5) = "-R$ 0,05"`, `parseMoney` nos 5 formatos do SPEC + inválido, `newId` 10.000 ids únicos.

### T-003 · Tema e tokens · `done` · deps: T-001 · parallel: yes
files: `lib/core/theme/app_colors.dart`, `lib/core/theme/app_spacing.dart`, `lib/core/theme/app_palettes.dart`, `lib/core/theme/app_theme.dart`
contrato: SPEC §7.1 + paletas do `CLAUDE.md`
aceite: `AppColors.lerp`/`copyWith` implementados; `AppTheme.light().extension<AppColors>()` não nulo.

### T-004 · Persistência e configurações · `done` · deps: T-001 · parallel: yes
files: `lib/core/services/record_store.dart`, `lib/core/services/collection_repository.dart`, `lib/core/models/app_settings.dart`, `lib/core/services/settings_controller.dart`, `test/core/collection_repository_test.dart`
contrato: SPEC §3.5–3.6
aceite: testes com `MemoryRecordStore`: upsert/byId/delete/deleteWhere/replaceAll, `version` incrementa, `all` cacheado (mesma instância entre leituras sem mudança), notifica uma vez em `upsertAll`; `AppSettings.fromMap({})` = padrões; `HiveRecordStore` converte mapas aninhados para `Map<String,dynamic>`.

## Fase 1 — Domínio

### T-005 · Entidades · `done` · deps: T-002
files: `lib/features/accounts/domain/account.dart`, `lib/features/cards/domain/payment_card.dart`, `lib/features/categories/domain/transaction_category.dart`, `lib/features/transactions/domain/transaction.dart`, `lib/features/recurring/domain/recurring_rule.dart`, `test/features/entities_test.dart`
contrato: SPEC §4
aceite: round-trip `fromMap(toMap(x)) == x` (implemente `==`/`hashCode`) para cada entidade; enum desconhecido → primeiro valor; campos opcionais ausentes → null.

### T-006 · Faturas · `done` · deps: T-005 · parallel: yes
files: `lib/features/cards/domain/invoice_cycle.dart`, `lib/features/cards/domain/invoice.dart`, `test/features/cards/invoice_test.dart`
contrato: SPEC §5.1–5.2
aceite: os 4 exemplos do SPEC §5.1; fechamento dia 31 em fevereiro; virada de ano (fecha 25, vence 5: compra 28/12/2026 → fecha 25/01/2027 → vence 05/02/2027); estorno abate; pagamento parcial → remaining; status open/closed/paid/overdue; `usedLimitCents` com parcelas futuras.

### T-007 · Parcelas e recorrência · `done` · deps: T-005 · parallel: yes
files: `lib/features/transactions/domain/installments.dart`, `lib/features/recurring/domain/recurrence.dart`, `test/features/installments_recurrence_test.dart`
contrato: SPEC §5.3–5.4
aceite: 100,00 em 3x = 33,34 + 33,33 + 33,33; datas a partir de 31/01; monthly com start dia 31 → 28/02, 31/03, 30/04; weekly; yearly 29/02 → 28/02 em não-bissexto; endDate respeitado; `existingIds` evita duplicata; `active=false` → vazio.

### T-008 · Saldos e categorias · `done` · deps: T-005 · parallel: yes
files: `lib/features/accounts/domain/balances.dart`, `lib/features/categories/domain/category_spending.dart`, `test/features/balances_spending_test.dart`
contrato: SPEC §5.5–5.6
aceite: planned não afeta saldo; transfer move entre contas; débito afeta conta do cartão; crédito não afeta conta; invoicePayment debita; gasto por categoria inclui cartão, exclui transfer/income; budget ordenado por ratio.

### T-009 · Previsão · `done` · deps: T-006, T-007, T-008
files: `lib/features/forecast/domain/forecast.dart`, `test/features/forecast_test.dart`
contrato: SPEC §5.7
aceite: cenário com 2 contas, 2 cartões de crédito (1 sem conta de pagamento), compra parcelada, assinatura no cartão, salário recorrente na conta, boleto provisionado atrasado (entra hoje), transferência (zero no consolidado): verificar eventos, `months[i].endBalanceCents`, `firstNegativeDate`, ocorrência já materializada não duplica, fatura paga não gera evento.

### T-009b · Correções da revisão do domínio · `done` · deps: T-009
files: `lib/features/cards/domain/invoice.dart`, `lib/features/transactions/domain/{transaction,installments}.dart`, `lib/features/recurring/domain/recurring_rule.dart`, `lib/core/services/collection_repository.dart`, `lib/core/models/app_settings.dart`, `lib/core/utils/formatters.dart` + testes
aceite: (1) parcelas com fechamento 29/30/31 cruzando fev e mês de 30 dias caem uma por fatura consecutiva; (2) `replaceAll` grava novos antes de apagar antigos; (3) registro corrompido é pulado no construtor do repositório (sem derrubar boot); (4) `Transaction`/`RecurringRule` normalizam datas no construtor; (5) `RecurringRule.materializedUntil` (SPEC §4.5) com round-trip; (6) `buildInstallments` lança `ArgumentError` se `count < 1` ou `count > amountCents`; (7) `invoiceKey` malformado é ignorado; (8) `build` sem copiar listas (`followedBy`); (9) `upsertAll` monta entradas antes de mutar; (10) `AppSettings` usa `enumByName`; (11) `parseMoney` rejeita > 13 dígitos inteiros.

## Fase 2 — App

### T-010 · Bootstrap, Ledger, Shell, Onboarding · `done` · deps: T-003, T-004, T-009
files: `lib/main.dart`, `lib/app/app.dart`, `lib/app/bootstrap.dart`, `lib/app/app_scope.dart`, `lib/app/ledger.dart`, `lib/app/seed.dart`, `lib/app/home_shell.dart`, `lib/features/onboarding/presentation/onboarding_page.dart`, + placeholders `lib/features/{dashboard,forecast,cards,accounts,transactions,recurring,categories,settings}/presentation/<x>_page.dart` (classes `DashboardPage`, `ForecastPage`, `CardsPage`, `AccountsPage`, `TransactionsPage`, `RecurringPage`, `CategoriesPage`, `SettingsPage`, cada um `StatelessWidget` com `Center(Text(...))`), `test/app/ledger_test.dart`
contrato: SPEC §6, §7.3, §7.4
aceite: `bootstrap({RecordStore Function(String box)? storeFactory, DateTime Function()? clock})` permite memória em teste; seed de categorias padrão (12 despesa, 4 receita, sem nomes de empresas reais); seed demo cria ≥ 2 bancos fictícios, 4 cartões (3 crédito, 1 débito), 3 contas, ~40 transações dos últimos 3 meses + parcelas futuras, 4 recorrentes; Ledger memoiza (teste: `forecast` idêntico entre chamadas sem mudança, recalcula após upsert).

### T-010b · Status de recorrência materializada + robustez do onboarding · `done` · deps: T-010
files: `lib/features/recurring/domain/recurrence.dart`, `test/features/installments_recurrence_test.dart`, `lib/features/onboarding/presentation/onboarding_page.dart`
aceite: regra de status do SPEC §5.4; onboarding com try/finally e SnackBar de erro.

### T-011 · Widgets compartilhados · `done` · deps: T-010
files: `lib/core/widgets/*.dart` (um arquivo por widget do SPEC §7.2 ou agrupados em ≤ 4 arquivos), `lib/core/widgets/widgets.dart` (barrel)
contrato: SPEC §7.2

## Fase 3 — Telas (todas parallel: yes, deps: T-011)

### T-012 · Painel · `done` · files: `lib/features/dashboard/presentation/*`
### T-013 · Previsão · `done` · files: `lib/features/forecast/presentation/*`
### T-014 · Cartões e faturas · `done` · files: `lib/features/cards/presentation/*` (lista por banco, form cartão, detalhe com faturas, pagar fatura)
### T-015 · Contas e transferência · `done` · files: `lib/features/accounts/presentation/*`
### T-016 · Transações · `done` · files: `lib/features/transactions/presentation/*` (lista/tabela, filtros, form com parcelas/provisionado/boleto, confirmar provisionado, excluir grupo). Expõe `Future<void> showTransactionForm(BuildContext context, {Transaction? initial})` usado pelo shell.
### T-017 · Recorrentes · `done` · files: `lib/features/recurring/presentation/*`
### T-018 · Categorias e orçamento · `done` · files: `lib/features/categories/presentation/*`
### T-019 · Ajustes, backup e CSV · `done` · files: `lib/features/settings/presentation/*`, `lib/core/services/backup_service.dart`, `test/core/backup_service_test.dart`
contrato comum: SPEC §6.3, §7.3 (tabela Simples/Ultra), `CLAUDE.md` padrões visuais. Ler dados só via `AppScope.of(context)` + `ListenableBuilder(listenable: ledger)`.

## Fase 4 — Integração

### T-020a · Polimento app/dados (revisão Fase 3) · `done` · parallel: yes
files: `lib/app/{bootstrap,ledger}.dart`, `lib/core/services/backup_service.dart`, `lib/core/theme/app_palettes.dart`, `lib/features/categories/presentation/*`, `lib/features/transactions/presentation/transaction_row.dart`, `test/app/*`, `test/core/backup_service_test.dart`

### T-020b · Polimento dos formulários (revisão Fase 3) · `done` · parallel: yes
files: `lib/features/{cards,accounts,recurring}/presentation/*_form.dart|*_dialog.dart`, `lib/features/transactions/presentation/{transaction_form,transactions_page}.dart`, `test/features/{transactions,cards,recurring}/*`

### T-020 · Smoke test e polimento · `done` · deps: T-012..T-019 (absorvido por T-020a/b)
files: `test/app/smoke_test.dart`, ajustes mecânicos
aceite: app sobe com seed demo em memória, navega 8 páginas nos modos Simples e Ultra, abre form de transação; `CHECK OK`.

### T-021 · Documentação · `done` · deps: T-020
files: `CONTEXT.md`, `CLAUDE.md` (estrutura), `README.md`, `ROADMAP.md`

## Fase 5 — Previsibilidade avançada

> Domínio primeiro (T-030..T-032, Dart puro + testes), depois Ledger (T-033), depois UI (T-034..T-038).
> Contratos: SPEC §4.2, §5.1–5.2 (histórico de ciclo), §5.8, §5.9, §6.2, §7.3 "Previsibilidade avançada".

### T-030 · Histórico de ciclo do cartão (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/cards/domain/payment_card.dart`, `lib/features/cards/domain/invoice_cycle.dart`, `lib/features/cards/domain/invoice.dart`, `test/features/cards/card_cycle_test.dart`
contrato: SPEC §4.2 (`CardCycle`, `cycleHistory`, `cycleOn`, `withCycleChange`), §5.1 (`invoiceDueMonth` via `cycleOn`; `invoiceClosingDate`/`invoiceDueDate` com `{DateTime? cycleDate}`; `purchaseDueDate`), §5.2 (datas da fatura pelo maior `t.date` dos itens; sem itens → `dueMonth.firstDay`)
aceite:
- `PaymentCard.fromMap` sem `cycleHistory`, com `null` e com item inválido → lista vazia / item ignorado; round-trip `fromMap(toMap(c)) == c` com 2 ciclos.
- `cycleOn`: histórico `[until 01/12/2026 (fecha 5, vence 12)]`, atual fecha 25/vence 5 → 30/11 usa (5, 12); 01/12 usa (25, 5).
- `withCycleChange` com dias iguais → mesma instância; data ≤ último `until` → `ArgumentError`; caso normal empilha o ciclo antigo.
- Transição (fecha 5/vence 12 → fecha 25/vence 5 a partir de 01/12/2026): compra 20/11 → fatura `2026-12` vence 12/12/2026; compra 02/12 → fatura `2027-01` vence 05/01/2027; pagamento com `invoiceKey` `2026-11` feito antes da mudança continua quitando a fatura de nov.
- Parcelado 3x comprado 15/10/2026 no cenário acima: meses `2026-11`, `2026-12`, `2027-01`; fatura `2027-01` vence 05/01/2027.
- `purchaseDueDate(14/11/2026, fecha 5/vence 12) == 12/12/2026`.
- `test/features/cards/invoice_test.dart` e `test/features/entities_test.dart` passam **sem alteração**.

### T-031 · Linha do tempo de vencimentos e cobertura (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/forecast/domain/invoice_timeline.dart`, `test/features/forecast/invoice_timeline_test.dart`
contrato: SPEC §5.9 (`InvoiceDue`, `invoiceTimeline`)
aceite (fixture com `ForecastService.compute` + `InvoiceService.build`, hoje 14/11/2026):
- conta A com 1.000,00 e cartão X (pago pela conta A) com fatura de 1.500,00 vencendo em 20 dias → `uncovered`, `accountBalanceAfterCents == -50000`.
- cartão Y sem `paymentAccountId` → `hasAccount == false`, `accountBalanceAfterCents == null`, `needsAttention`.
- cartão cuja conta de pagamento está arquivada → tratado como sem conta.
- fatura vencida não paga → `date == today`, `overdue == true`.
- fatura vencendo em 90 dias não aparece com `days: 60`; aparece com `days: 120` (previsão de 6 meses).
- duas faturas no mesmo dia na mesma conta → mesmo `accountBalanceAfterCents` (inclui ambas); salário recorrente no mesmo dia entra no saldo-após.
- fatura paga não aparece.

### T-032 · Insights de cartão (domínio) · `done` · deps: T-030 · parallel: yes (com T-031)
files: `lib/features/cards/domain/card_insights.dart`, `test/features/cards/card_insights_test.dart`
contrato: SPEC §5.8 (`CardPurchaseOption`, `bestCardsToBuy`, `InstallmentCommitment`, `installmentCommitments`, `cardsWithoutPaymentAccount`)
aceite:
- exemplo A/B/C do SPEC §5.8 → ordem A, B, C com `daysUntilDue` 28, 21, 13; A com usado ≥ limite → ordem B, C, A; débito e arquivado excluídos; limite 0 → `hasLimit == false`.
- `daysUntilDue` correto atravessando mudança de horário (datas em outubro e fevereiro).
- `installmentCommitments`: 100,00 em 3x comprado 10/11/2026 no cartão fecha 5/vence 12, `from: 2026-12` → 12 entradas; dez 33,34, jan 33,33, fev 33,33, demais 0 com `byCard` vazio; compra à vista e recorrência projetada na mesma fatura não entram; dois cartões somam em `totalCents` e separam em `byCard`.
- `cardsWithoutPaymentAccount`: `null` e conta inexistente/arquivada entram; cartão arquivado não entra.

### T-033 · Ledger: visões da Fase 5 · `done` · deps: T-020a, T-031, T-032
files: `lib/app/ledger.dart`, `test/app/ledger_insights_test.dart`
contrato: SPEC §6.2 (`invoiceTimeline`, `bestCardsToday`, `installmentCommitments`, `cardsWithoutPaymentAccount`)
aceite: cada getter memoizado (mesma instância entre leituras sem mudança) e zerado em `_invalidate`; após `cards.upsert` recalcula; `invoiceTimeline` usa as faturas de `invoicesFor` de todos os cartões de crédito (ids batem com `forecast.events`).

### T-034 · Painel: alerta de cobertura · `done` · deps: T-033 · parallel: yes
files: `lib/features/dashboard/presentation/dashboard_summary.dart`, `lib/features/dashboard/presentation/dashboard_sections.dart`, `lib/features/dashboard/presentation/dashboard_page.dart`, `test/features/dashboard/dashboard_page_test.dart`
contrato: SPEC §7.3 "Previsibilidade avançada", linha "Cobertura de faturas". `DashboardSummary` ganha `List<InvoiceDue> attention` (= `ledger.invoiceTimeline.where((d) => d.needsAttention)`). Novos widgets em `dashboard_sections.dart`: `CoverageBanner({required List<InvoiceDue> items})` (Simples) e `CoverageCard({required List<InvoiceDue> items, required Map<String, Account> accounts})` (Ultra), logo após o `NegativeBalanceBanner`.
aceite: widget test com conta sem saldo para a fatura → Simples mostra banner com a contagem; Ultra mostra a seção com nome da conta e "Sem conta de pagamento" para cartão sem conta; sem pendências → nada renderizado. Cores via `context.colors`.

### T-035 · Previsão: linha do tempo de vencimentos (Ultra) · `done` · deps: T-033 · parallel: yes
files: `lib/features/forecast/presentation/forecast_invoice_timeline.dart`, `lib/features/forecast/presentation/forecast_page.dart`, `test/features/forecast/forecast_page_test.dart`
contrato: SPEC §7.3 linha "Linha do tempo de vencimentos". `class InvoiceTimelineSection extends StatelessWidget { const InvoiceTimelineSection({super.key, required List<InvoiceDue> items, required Map<String, Account> accounts}); }` no ramo Ultra de `ForecastPage`, antes de "Saldo diário".
aceite: Ultra mostra cabeçalho por dia (`formatShortDate`), linha com nome do cartão, conta ou "Sem conta", valor e saldo-após (`danger` se < 0), badge "Vencida"; Simples não renderiza a seção; lista vazia → `EmptyState`.

### T-036 · Previsão: parcelas já comprometidas (Ultra) · `done` · deps: T-035
files: `lib/features/forecast/presentation/forecast_installments.dart`, `lib/features/forecast/presentation/forecast_page.dart`, `test/features/forecast/forecast_page_test.dart`
contrato: SPEC §7.3 linha "Compromisso de parcelas". `class InstallmentCommitmentsSection extends StatelessWidget { const InstallmentCommitmentsSection({super.key, required List<InstallmentCommitment> items, required Map<String, PaymentCard> cards}); }` após "Vencimentos (60 dias)", só Ultra.
aceite: 12 linhas (`formatMonth`), coluna Total + uma coluna por cartão com algum valor no período (nome do cartão), valores com `MoneyText`; rolagem horizontal (`SingleChildScrollView(scrollDirection: Axis.horizontal)`); tudo zerado → `EmptyState` "Nenhuma parcela futura".

### T-037 · Cartões: melhor cartão hoje e cartão sem conta · `done` · deps: T-033 · parallel: yes
files: `lib/features/cards/presentation/best_card_panel.dart`, `lib/features/cards/presentation/cards_page.dart`, `lib/features/cards/presentation/card_tile.dart`, `test/features/cards/cards_page_test.dart`
contrato: SPEC §7.3 linhas "Melhor cartão" e "Cartão sem conta". `class BestCardPanel extends StatelessWidget { const BestCardPanel({super.key, required List<CardPurchaseOption> options, required bool ultra}); }` no topo da lista de `CardsPage`. `CardTile` ganha `bool missingPaymentAccount` (padrão false) → `StatusBadge` com `colors.warning`.
aceite: Simples mostra 1 linha com o 1º `hasLimit` e "vence em N dias"; Ultra mostra tabela com todos os cartões de crédito ativos na ordem do domínio; nenhum `hasLimit` → Simples oculta o painel; badge aparece só para cartões de `ledger.cardsWithoutPaymentAccount`.

### T-038 · Form de cartão: mudança de ciclo com vigência · `done` · deps: T-030, T-020b · parallel: yes
files: `lib/features/cards/presentation/card_form.dart`, `test/features/cards/card_form_test.dart` (cria ou estende)
contrato: SPEC §4.2 `withCycleChange`, §7.3 linha "Mudança de ciclo". Em `_save`: edição de cartão de crédito com `closingDay`/`dueDay` alterados **e** `s.transactions.all.any((t) => t.cardId == old.id)` → diálogo com `DateField` "Vale a partir de" (padrão `s.ledger.today`); salva `old.copyWith(<demais campos>).withCycleChange(closingDay:, dueDay:, effectiveFrom:)`; cancelar não salva; `ArgumentError` → mensagem no diálogo, sem fechar. Sem transações → só troca os dias (histórico intacto). Todo `copyWith` preserva `cycleHistory`.
aceite: widget test: cartão com transação, muda vencimento, confirma data → cartão salvo tem `cycleHistory.length == 1` com os dias antigos; cartão sem transações → `cycleHistory` vazio; editar só o nome preserva `cycleHistory`.

## Fase 6 — Pendências conhecidas

> Origem: CONTEXT.md §12. T-040..T-044 não têm arquivos em comum: todas `parallel: yes`.
> Contratos: SPEC §3.5 (import tudo-ou-nada), §4 (`copyWith` com sentinela), §5.1–5.2 (linha de fechamentos), §5.7, §5.9, §6.2.

### T-040 · Import de backup tudo-ou-nada · `done` · deps: — · parallel: yes
files: `lib/core/services/backup_service.dart`, `test/core/backup_service_test.dart`
contrato: SPEC §3.5 "Import de backup tudo-ou-nada". Assinatura inalterada: `static Future<void> importJson(AppServices s, String json)`. Retrato (`s.accounts.all`, `s.cards.all`, `s.categories.all`, `s.transactions.all`, `s.recurring.all`, `s.settings.value`) tirado depois de `_parse` e antes da 1ª gravação. Gravações + `materializeRecurring(s)` dentro de `try`; no `catch (e, st)`: `replaceAll(retrato)` em cada repositório e `settings.update((_) => retrato)`, cada um em `try` próprio, depois `Error.throwWithStackTrace(e, st)`. Sem mudar `CollectionRepository`/`RecordStore`.
aceite:
- Teste com `storeFactory` que devolve, para `fm_transactions`, um `MemoryRecordStore` cujo `putAll` lança **uma vez** (flag `failNext`): `importJson` de um backup válido lança; depois disso `accounts/cards/categories/transactions/recurring.all` (comparar ids e `toMap`) e `settings.value` são iguais aos de antes do import.
- Mesmo cenário falhando em `fm_settings` (`put` lança uma vez) → tudo restaurado.
- Testes existentes de `backup_service_test.dart` passam sem alteração (round-trip, órfãos, JSON inválido, campo inválido, CSV).

### T-041 · Previsão cobre os 60 dias da linha do tempo · `done` · deps: — · parallel: yes
files: `lib/features/forecast/domain/forecast.dart`, `test/features/forecast_test.dart`, `lib/app/ledger.dart`, `test/app/ledger_insights_test.dart`
contrato: SPEC §5.7 (`ForecastService.compute({..., int months = 6, int minDays = 0})`, passo 2), §5.9 (nota final), §6.2 (`static const int invoiceTimelineDays = 60;`; `forecast` passa `minDays: invoiceTimelineDays`; `invoiceTimeline` usa `days: invoiceTimelineDays`). Remover o comentário de "59 dias no pior caso" em `ledger.dart`.
aceite:
- `forecast_test.dart`: hoje 31/01/2027, `months: 3` → `minDays: 0` dá `daily.last.date == 31/03/2027`; `minDays: 60` dá `daily.last.date == 01/04/2027` e `months.length == 3`; fatura com vencimento 01/04/2027 gera evento só com `minDays: 60`.
- `ledger_insights_test.dart`: clock 31/01/2027, `forecastMonths: 3`, cartão com fatura vencendo 01/04/2027 → aparece em `ledger.invoiceTimeline`; `ledger.forecast.months.length == 3`.
- Demais testes de previsão, Ledger e telas passam sem alteração.

### T-042 · `copyWith` limpa anuláveis: `Transaction` e `RecurringRule` · `done` · deps: — · parallel: yes
files: `lib/features/transactions/domain/transaction.dart`, `lib/features/recurring/domain/recurring_rule.dart`, `test/features/copy_with_clear_test.dart` (novo)
contrato: SPEC §4 "`copyWith` e campos anuláveis". Por arquivo: `const Object _keep = Object();`. `Transaction.copyWith`: `categoryId`, `accountId`, `cardId`, `toAccountId`, `invoiceKey`, `installmentGroupId`, `installmentIndex`, `installmentCount`, `recurringId`, `notes` viram `Object? x = _keep`. `RecurringRule.copyWith`: `categoryId`, `accountId`, `cardId`, `endDate`, `materializedUntil` idem. Demais parâmetros inalterados. Não alterar chamadores.
aceite:
- Para cada campo anulável listado: `copyWith()` mantém o valor; `copyWith(campo: null)` → `null`; `copyWith(campo: v)` → `v`.
- `RecurringRule.copyWith(endDate: DateTime(2026, 12, 1, 9))` normaliza para `DateTime(2026, 12, 1)` (vai pelo construtor).
- `Transaction.copyWith(notes: null)` sobre transação com notas → `toMap()` sem notas e `fromMap(toMap())` igual.
- `test/features/entities_test.dart` e todo o resto passam sem alteração; `flutter analyze` sem avisos.

### T-043 · `copyWith` limpa anuláveis: `PaymentCard` e `TransactionCategory` · `done` · deps: — · parallel: yes
files: `lib/features/cards/domain/payment_card.dart`, `lib/features/categories/domain/transaction_category.dart`, `test/features/copy_with_clear_card_category_test.dart` (novo)
contrato: SPEC §4 "`copyWith` e campos anuláveis". `PaymentCard.copyWith({..., Object? paymentAccountId = _keep, ...})`; `TransactionCategory.copyWith({..., Object? monthlyBudgetCents = _keep})`. `withCycleChange` e `cycleHistory` intactos. Não alterar chamadores.
aceite:
- `card.copyWith(paymentAccountId: null).paymentAccountId == null`; `copyWith()` mantém; `copyWith(paymentAccountId: 'acc_x')` troca; `cycleHistory` preservado em todos os casos.
- `category.copyWith(monthlyBudgetCents: null)` remove o orçamento; `copyWith()` mantém; valor troca.
- `card_form_test.dart`, `card_cycle_test.dart`, `entities_test.dart` e `categories_page_test.dart` passam sem alteração.

### T-044 · Fatura de transição na mudança de ciclo (sem fusão) · `done` · deps: — · parallel: yes
files: `lib/features/cards/domain/invoice_cycle.dart`, `lib/features/cards/domain/invoice.dart`, `test/features/cards/card_cycle_test.dart`
contrato: SPEC §5.1 "Linha de fechamentos e fatura de transição" (regras 1–10) e §5.2. Em `invoice_cycle.dart`: `invoiceDueMonth`, `invoiceClosingDate`, `invoiceDueDate`, `purchaseDueDate` com as mesmas assinaturas e novo comportamento com histórico; nova função pública `YearMonth installmentDueMonth(DateTime firstDate, int index, PaymentCard card)`. Helper privado de sequência de fechamentos (ex.: `List<({DateTime closing, YearMonth dueMonth, int dueDay})> _closings(PaymentCard card, YearMonth from, YearMonth to)`). Histórico vazio → atalho com as fórmulas originais. Em `invoice.dart`: parcelas usam `installmentDueMonth(firstDate, index, card)` no lugar de `invoiceDueMonth(firstDate, card).addMonths(index - 1)`; `_toInvoice` segue passando `cycleDate` (usado só no fallback). `PaymentCard.cycleOn` não muda.
aceite (substituir os testes do grupo "transição de ciclo" e o grupo "fatura fundida (regressão)" pelos exemplos do SPEC §5.1):
- Fecha 5/vence 12 → fecha 25/vence 5 a partir de 01/12/2026: compra 04/11 → `2026-11` vence 12/11; compras 20/11 e 02/12 → `2027-01` vence 05/01/2027 e fecha 25/12/2026; `InvoiceService.build` não gera fatura `2026-12`; parcelado 3x com 1ª em 15/10 → `2026-11`, `2027-01`, `2027-02`; pagamento `invoiceKey` `2026-11` feito antes da mudança quita nov.
- Fecha 5/vence 12 → fecha 20/vence 27 a partir de 15/11/2026: compras 10/11 e 16/11 → `2026-12`, `closingDate` 20/12, `dueDate` 27/12; fatura `2026-12` com só um item do ciclo antigo tem as mesmas datas (independe dos itens); compra 04/11 → nov (12/11).
- Fecha 25/vence 5 → fecha 5/vence 12 a partir de 01/12/2026: compra 24/11 → `2026-12` (05/12); compra 28/11 → `2027-01` (fecha 05/01/2027, vence 12/01/2027).
- Para toda compra dos cenários acima: `purchaseDueDate(d, card) == dueDate` da fatura de `InvoiceService.build` que contém a compra.
- Duas mudanças seguidas (histórico com 2 ciclos) → `dueMonth` das faturas estritamente crescente e sem fatura duplicada.
- Sem histórico: `installmentDueMonth(d1, i, card) == invoiceDueMonth(d1, card).addMonths(i - 1)` para i = 1..12.
- `test/features/cards/invoice_test.dart`, `card_insights_test.dart`, `entities_test.dart` e `card_form_test.dart` passam **sem alteração**.

### T-046 · Correções da revisão da Fase 6 · `done` · deps: T-040..T-044
- (a) Pagamento com `invoiceKey` de mês descartado pela mudança de ciclo é remapeado para o próximo fechamento mantido (abate a fatura de transição; sem dupla contagem na previsão). Helper público `invoiceMonthForKey(YearMonth, PaymentCard)` em `invoice_cycle.dart`; usado em `InvoiceService.build`. SPEC §5.1/§5.2 atualizada (remove o "limite conhecido").
- (b) `card_form.dart`: texto "Faturas anteriores não mudam" e comentários de `_lastTransactionDay`/`_minFrom` e `PaymentCard.withCycleChange` alinhados à fatura de transição.
- (c) `copyWith`: `identical(x, _keep)` no lugar de `x == _keep` (4 entidades).
- (d) `Ledger._projectedCardOccurrences` usa o mesmo fim da previsão (`max(fim dos meses, hoje + invoiceTimelineDays)`).

### T-047 · Memoizar a linha de fechamentos por cartão · `todo` · deps: T-046
files: `lib/features/cards/domain/invoice_cycle.dart` (+ teste). Hoje cada `invoiceDueMonth`/`installmentDueMonth`/`_keptFor` reconstrói segmentos e fechamentos desde a 1ª mudança: O(T × meses × segmentos) por cartão com histórico, crescendo com o tempo. Memoizar por instância de `PaymentCard` (ex.: `Expando`, estendido sob demanda) com busca binária por data e por `dueMonth`, ou montar a linha uma vez em `InvoiceService.build`. Aceite: resultados idênticos (todos os testes de cards passam sem alteração).

### T-045 · Teste em dispositivo Android real · `cancelado` (v3: só Windows, Android removido — `docs/V3_DIRECTION.md`) · deps: T-040..T-044
files: — (nenhum código; registrar resultado em `CONTEXT.md` §12)
passos: `flutter build apk` (ou `flutter run -d <id>`) em aparelho físico; rodar onboarding com dados de exemplo; navegar pelas 8 páginas nos modos Simples e Ultra; criar compra parcelada, pagar fatura, mudar ciclo de um cartão; exportar e importar backup (seletor de arquivo do Android); girar a tela e testar o drawer.
aceite: sem exceção nem overflow visível; backup exportado reimporta no mesmo aparelho; dados persistem após fechar e reabrir o app. Usuário marca `done` e remove o item de CONTEXT.md §12.

## Fase 7 — Identidade visual e polimento

> Origem: `docs/V3_DIRECTION.md` (Visual). Contratos: SPEC §3.3 (`formatPercent`), §5.10, §6.2 (getters Fase 7), §7.1, §7.2, §7.3 (shell e tabela "Identidade visual e polimento (Fase 7)").
> Modo Simples só herda fonte, paleta e microanimações: nada de delta, sparkline, avatar de banco nem ordenação nele.
> Ondas (tarefas da mesma onda têm arquivos disjuntos): **A** T-050, T-051, T-054, T-055, T-058, T-063, T-065 · **B** T-052, T-053, T-056, T-059, T-060, T-066 · **C** T-057 · **D** T-061, T-062, T-064 · **E** T-067.
> Testes de widget com `SkeletonPulse` usam `pump(Duration)`, nunca `pumpAndSettle` (animação em loop).

### T-050 · Paleta quente, fontes no pubspec e `AppMotion` · `done` · deps: — · parallel: yes
files: `pubspec.yaml`, `lib/core/theme/app_colors.dart`, `lib/core/theme/app_spacing.dart`, `test/core/theme_test.dart`
contrato: SPEC §7.1. `pubspec.yaml` → em `flutter:` acrescentar `fonts:` com família `IBMPlexSans` (`assets/fonts/IBMPlexSans-Regular.ttf` weight 400, `-Medium.ttf` 500, `-SemiBold.ttf` 600) e `SourceSerif4` (`SourceSerif4-Regular.ttf` 400, `SourceSerif4-Semibold.ttf` 600). Nenhuma dependência nova. `AppColors.light`: `background 0xFFF6F5F2`, `sidebar 0xFFECEAE5`; `AppColors.dark`: `background 0xFF161514`, `surface 0xFF1F1E1C`, `sidebar 0xFF2A2826`; demais tokens inalterados. `app_spacing.dart`: `abstract final class AppMotion { static const fast = Duration(milliseconds: 150); static const normal = Duration(milliseconds: 200); static const Curve curve = Curves.easeOutCubic; }` (importar `package:flutter/animation.dart`).
aceite:
- `theme_test.dart`: asserts dos 6 valores de superfície novos (claro e escuro) e de `primary` inalterado (`0xFF42A5F5` / `0xFF81D4FA`); `AppMotion.fast.inMilliseconds == 150`, `normal == 200`.
- `flutter pub get` sem erro; testes existentes passam.

### T-051 · Tipografia: `AppFonts`, `AppText` e `TextTheme` · `done` · deps: — · parallel: yes
files: `lib/core/theme/app_text.dart` (novo), `lib/core/theme/app_theme.dart`, `test/core/app_text_test.dart` (novo)
contrato: SPEC §7.1 `app_text.dart` e `app_theme.dart`. `AppText.tabular(style)` = `style.copyWith(fontFeatures: AppText.tabularFigures)`. `AppText.screenTitle(context)` = `Theme.of(context).textTheme.titleLarge!`. `AppText.kpi(context)` = `TextStyle(fontFamily: AppFonts.serif, fontSize: 22, fontWeight: FontWeight.w600, color: context.colors.textPrimary, fontFeatures: tabularFigures)`. Em `AppTheme._build`: `fontFamily: AppFonts.sans`; `titleLarge` ganha `fontFamily: AppFonts.serif` (20, w600); demais estilos do `textTheme` sem `fontFamily` (herdam sans); `tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: AppRadius.chipBorder), textStyle: TextStyle(fontSize: 12, color: c.textPrimary), waitDuration: Duration(milliseconds: 300))`. Nome de família só em `app_text.dart`.
aceite (`app_text_test.dart`):
- `AppTheme.light().textTheme.titleLarge!.fontFamily == AppFonts.serif`; `bodyMedium!.fontFamily == AppFonts.sans` (claro e escuro).
- `AppText.tabular(TextStyle()).fontFeatures` contém `FontFeature.tabularFigures()`.
- Widget test: `AppText.kpi(context)` sob `AppTheme.dark()` tem `fontFamily == AppFonts.serif`, `fontSize == 22` e `color == AppColors.dark.textPrimary`.
- `AppTheme.light().tooltipTheme.waitDuration == Duration(milliseconds: 300)`.

### T-052 · `MoneyText` tabular, `KpiTile` serif com `trend`, tooltip no `LimitBar` · `done` · deps: T-050, T-051 · parallel: yes (com T-053, T-056, T-059, T-060, T-066)
files: `lib/core/widgets/money.dart`, `lib/core/widgets/indicators.dart`, `test/core/widgets_test.dart`
contrato: SPEC §7.2. `MoneyText`: estilo final passa por `AppText.tabular(...)`. `KpiTile({..., Widget? trend})`: valor com `AppText.kpi(context)` (+ `color` se dado); `trend` renderizado entre o valor e a `caption` com `SizedBox(height: AppSpace.xs)` antes; o `MoneyText` do valor fica dentro de `AnimatedSwitcher(duration: AppMotion.fast, child: MoneyText(..., key: ValueKey(cents)))`. `LimitBar`: envolver em `Tooltip(message: 'Usado ${formatMoney(used)} de ${formatMoney(limit)} (${pct}%)')` com `pct = limit <= 0 ? 0 : (used * 100 / limit).round()`; com `hideValues` ligado a mensagem usa `formatMoney(..., hidden: true)` (ler como o `MoneyText` já lê).
aceite (`widgets_test.dart`, acrescentar):
- `MoneyText` renderiza `Text` cujo `style.fontFeatures` contém `FontFeature.tabularFigures()`.
- `KpiTile(trend: Text('X'))` mostra 'X'; sem `trend` não quebra; o `Text` do valor tem `fontFamily == AppFonts.serif`.
- Trocar `cents` de um `KpiTile` e `pumpAndSettle` mostra o novo valor sem exceção.
- `LimitBar(used: 5000, limit: 10000)` tem `Tooltip` com mensagem contendo `(50%)`; `limit: 0` → `(0%)`.
- Testes existentes do arquivo passam.

### T-053 · `formatPercent` e `trend.dart` (`DeltaBadge`, `Sparkline`) · `done` · deps: T-050, T-051 · parallel: yes (com T-052, T-056, T-059, T-060, T-066)
files: `lib/core/utils/formatters.dart`, `test/core/utils_test.dart`, `lib/core/widgets/trend.dart` (novo), `test/core/trend_test.dart` (novo)
contrato: SPEC §3.3 `formatPercent` e §7.2 `trend.dart`. `DeltaBadge`: `ratio > 0` → "▲ " + `formatPercent(ratio.abs())`, `< 0` → "▼ ", `== 0` → "▲ 0,0%" em `textSecondary`; bom = `(ratio > 0) == higherIsBetter`; estilo `AppText.tabular(TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ...))`; envolto em `Tooltip(message: 'vs. mês anterior')`. `Sparkline`: `SizedBox(width, height, child: LineChart(LineChartData(lineTouchData: LineTouchData(enabled: false), titlesData: FlTitlesData(show: false), gridData: FlGridData(show: false), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: [FlSpot(i, values[i] / 100)], isCurved: false, barWidth: 1.5, dotData: FlDotData(show: false), color: color ?? context.colors.primary)])), duration: Duration.zero))`. Não exportar no barrel (T-057 faz).
aceite:
- `utils_test.dart`: `formatPercent(0.1234) == '12,3%'`, `formatPercent(-0.05) == '-5,0%'`, `formatPercent(0) == '0,0%'`, `formatPercent(1.0) == '100,0%'`, `formatPercent(0.00049) == '0,0%'`, `formatPercent(0.5, decimals: 0) == '50%'`.
- `trend_test.dart`: `DeltaBadge(ratio: 0.1)` mostra "▲ 10,0%" na cor `success`; `ratio: 0.1, higherIsBetter: false` → cor `danger`; `ratio: -0.2` → "▼ 20,0%" em `danger`; `ratio: null` → nenhum `Text`; `Sparkline(values: [1, 3, 2])` contém `LineChart`; `Sparkline(values: [5])` não contém `LineChart` e tem o tamanho pedido.

### T-054 · `BankAvatar` · `done` · deps: — · parallel: yes
files: `lib/core/widgets/bank_avatar.dart` (novo), `test/core/bank_avatar_test.dart` (novo)
contrato: SPEC §7.2 `bank_avatar.dart`. `bankInitials` e `bankColorIndex` públicas e puras no mesmo arquivo. Widget: `SizedBox.square(dimension: size)` + `DecoratedBox` (cor da paleta α 0.18, `AppRadius.chipBorder`) + iniciais centralizadas (11 px, w600, cor cheia da paleta; nome vazio → fundo `textSecondary` α 0.12 e "?" em `textSecondary`). Sem hex no widget (cor vem de `kEntityColors`). Não exportar no barrel (T-057 faz).
aceite:
- `bankInitials('Banco Alfa') == 'BA'`, `bankInitials('beta') == 'BE'`, `bankInitials('  x ') == 'X'`, `bankInitials('') == '?'`, `bankInitials('Banco do Sul Norte') == 'BD'`.
- `bankColorIndex` é determinístico (mesmo valor em 2 chamadas), ignora caixa e espaços nas pontas (`'Alfa'` == `' alfa '`), e fica em `0..kEntityColors.length-1`.
- Widget: `BankAvatar(bankName: 'Banco Alfa')` mostra "BA"; `size: 32` → `tester.getSize == Size(32, 32)`.

### T-055 · Skeleton e tela de boot · `done` · deps: — · parallel: yes
files: `lib/core/widgets/skeleton.dart` (novo), `lib/app/boot_screen.dart` (novo), `lib/main.dart`, `test/core/skeleton_test.dart` (novo)
contrato: SPEC §7.2 `skeleton.dart`, §2 `boot_screen.dart`, tabela Fase 7 "Skeleton de boot". `SkeletonPulse` é `StatefulWidget` com `AnimationController(duration: 900 ms)..repeat(reverse: true)` e `FadeTransition` 0.5↔1.0; com `MediaQuery.maybeOf(context)?.disableAnimations == true` não anima (opacidade 1). `class BootScreen extends StatelessWidget { const BootScreen({super.key}); }` → `MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ThemeMode.system, home: Scaffold(body: Row([SizedBox(width: 220, child: ColoredBox(color: context.colors.sidebar, child: SkeletonList(rows: 8))), Expanded(child: Padding(AppSpace.xl, SkeletonList(rows: 10)))])))` (usar `Builder` para ter `context` com o tema). `main.dart`: `WidgetsFlutterBinding.ensureInitialized(); runApp(const BootScreen()); final services = await bootstrap(); runApp(FinMeApp(services: services));`. Não exportar no barrel (T-057 faz).
aceite (`skeleton_test.dart`, sem `pumpAndSettle`):
- `SkeletonBox(width: 100, height: 12)` tem tamanho 100×12.
- `SkeletonList(rows: 4)` renderiza 4 `SkeletonBox`; após `pump(Duration(milliseconds: 450))` sem exceção.
- `BootScreen()` monta sem exceção e contém `SkeletonList`; com `MediaQuery(data: MediaQueryData(disableAnimations: true))` o `FadeTransition` fica com opacidade 1.

### T-056 · `SortableHeaderLabel` · `done` · deps: T-050 · parallel: yes (com T-052, T-053, T-059, T-060, T-066)
files: `lib/core/widgets/sortable_header.dart` (novo), `test/core/sortable_header_test.dart` (novo)
contrato: SPEC §7.2 `sortable_header.dart`. `InkWell` (só se `onTap != null`, `borderRadius: AppRadius.chipBorder`) com `Row(mainAxisSize: min)`: `Flexible(Text(label, maxLines: 1, overflow: ellipsis))` + `AnimatedOpacity(opacity: active ? 1 : 0, duration: AppMotion.fast)` sobre `AnimatedRotation(turns: ascending ? 0 : 0.5, duration: AppMotion.fast, child: Icon(Icons.arrow_upward, size: 14))`. `alignEnd` → `MainAxisAlignment.end` dentro de `Align(alignment: Alignment.centerRight)`. Não exportar no barrel (T-057 faz).
aceite:
- Tap chama `onTap` uma vez; `onTap: null` → sem `InkWell`.
- `active: false` → `AnimatedOpacity.opacity == 0`; `active: true, ascending: false` → `AnimatedRotation.turns == 0.5`.
- Cor do texto: ativo `textPrimary`, inativo `textSecondary`.

### T-057 · Barrel dos widgets novos · `done` · deps: T-053, T-054, T-055, T-056 · parallel: no
files: `lib/core/widgets/widgets.dart`
contrato: acrescentar `export 'bank_avatar.dart'; export 'skeleton.dart'; export 'sortable_header.dart'; export 'trend.dart';` em ordem alfabética com os existentes.
aceite: `flutter analyze` sem conflito de nomes; consumidores podem importar só `widgets.dart`.

### T-058 · Histórico mensal e variação (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/accounts/domain/monthly_history.dart` (novo), `test/features/accounts/monthly_history_test.dart` (novo)
contrato: SPEC §5.10 (regras 1–6). Dart puro. Reusa `signedEffectOn` (`balances.dart`) e `spendingByCategory` (`category_spending.dart`); `YearMonth` para os meses.
aceite (hoje = 14/11/2026, conta ativa A saldo inicial 100000, conta arquivada B saldo inicial 50000):
- `monthlyHistory(..., months: 6)` → 6 itens, `jun/2026..nov/2026` em ordem; sem transações todos com `endBalanceCents == 100000` (B fora).
- Receita paga 20000 em A em 10/09/2026 → set/out/nov = 120000, jun..ago = 100000. Despesa provisionada não muda nada.
- Transação paga em A com data 20/11/2026 (futura) entra no último `endBalanceCents` (igual a `accountBalances` das ativas) e fica fora do `expenseCents` de nov.
- Despesa de cartão de crédito paga 3000 em 05/10 → `expenseCents` de out = 3000 e `endBalanceCents` de out inalterado; pagamento de fatura de A em 10/11 reduz o saldo de nov.
- `expenseUntilDay(txs, 2026-10, 14)` conta despesas de 01–14/10 e ignora 15/10; `expenseUntilDay(txs, 2026-02, 31)` não lança (clamp em 28).
- `deltaRatio(1000, 1500) == 0.5`, `deltaRatio(-1000, -500) == 0.5`, `deltaRatio(1000, 0) == -1.0`, `deltaRatio(0, 10) == null`.

### T-059 · Ledger: `monthlyHistory` e `expenseMonthToDate` · `done` · deps: T-058 · parallel: yes (com T-052, T-053, T-056, T-060, T-066)
files: `lib/app/ledger.dart`, `test/app/ledger_insights_test.dart`
contrato: SPEC §6.2 (getters Fase 7). Campos `List<MonthSnapshot>? _history` e `({int current, int previous})? _expenseMtd`, ambos zerados em `_clearCache`. `monthlyHistory` usa `accounts.all`, `cards.all`, `transactions.all`, `today`, `months: 6`, resultado `List.unmodifiable`. `expenseMonthToDate`: `current = monthlyHistory.last.expenseCents`, `previous = expenseUntilDay(transactions.all, YearMonth.fromDate(today).prev(), today.day)`.
aceite:
- `identical(ledger.monthlyHistory, ledger.monthlyHistory)`; depois de `transactions.upsert(...)` a lista é outra e reflete a transação.
- `ledger.monthlyHistory.last.endBalanceCents == ledger.forecast.currentTotalCents` com dados de exemplo (`seedDemo`).
- Clock 14/11/2026, despesas pagas 1000 em 10/10 e 2000 em 20/10 e 500 em 05/11 → `expenseMonthToDate == (current: 500, previous: 1000)`.

### T-060 · Shell só desktop: sem drawer, sidebar colapsável · `done` · deps: T-050 · parallel: yes (com T-052, T-053, T-056, T-059, T-066)
files: `lib/app/home_shell.dart`, `test/app/smoke_test.dart`
contrato: SPEC §7.3 `HomeShell`. Remover `_scaffoldKey`, `AppBar`, `Drawer` e `closeDrawer`. `body` é sempre `Row([AnimatedContainer(width: collapsed ? 64 : 220, duration: AppMotion.normal, curve: AppMotion.curve, color: colors.sidebar, child: _Sidebar(collapsed: collapsed, ...)), Expanded(page)])`, `collapsed = MediaQuery.sizeOf(context).width < 900`. `_Sidebar(collapsed: true)`: topo "F" (ou só o ícone de app) no lugar de "FinMe"; `_NavTile` só com ícone centralizado dentro de `Tooltip(message: label)`; badge > 0 vira ponto `danger` 8×8 no canto do ícone; rodapé `IconButton(tooltip: ultra ? 'Modo: Ultra' : 'Modo: Simples', icon: Icon(ultra ? Icons.bolt : Icons.bolt_outlined), onPressed: () => onToggleMode(!ultra))`. `_NavTile` troca `Container` por `AnimatedContainer(duration: AppMotion.fast)` (fundo do item ativo). Com `collapsed: false` o visual atual se mantém. Evitar overflow durante a animação: rótulos só quando `!collapsed`, com `ClipRect` no conteúdo da sidebar.
aceite (`smoke_test.dart`):
- Substituir o teste "mobile 390x800 … Drawer" por "estreito 800x700 (Ultra): sidebar colapsada navega 8 páginas": navegar com `find.byTooltip(label)`, `pumpAndSettle`, sem exceção; `find.byType(Drawer)` e `find.byType(AppBar)` vazios; toggle de modo pelo tooltip 'Modo: Ultra' passa para Simples.
- Testes desktop 1400x900 (Simples e Ultra) passam sem alteração.
- Redimensionar de 1400 para 800 em um mesmo teste e `pumpAndSettle` → sem exceção de overflow.

### T-061 · Painel Ultra: KPIs com delta e sparkline · `done` · deps: T-052, T-057, T-059 · parallel: yes (com T-062, T-064)
files: `lib/features/dashboard/presentation/dashboard_summary.dart`, `lib/features/dashboard/presentation/dashboard_sections.dart`, `test/features/dashboard/dashboard_page_test.dart`
contrato: SPEC §7.3 tabela Fase 7 (linhas "Delta…" e "KPI Gasto no mês"). `DashboardSummary` ganha campos anuláveis preenchidos **só quando `ultra`** a partir do Ledger (sem recalcular): `List<int>? balanceTrend` (`monthlyHistory.map(endBalanceCents)`), `double? balanceDelta` (`deltaRatio(history[length-2].endBalanceCents, history.last.endBalanceCents)`), `int? monthExpenseCents` (`expenseMonthToDate.current`), `double? monthExpenseDelta` (`deltaRatio(previous, current)`), `List<int>? expenseTrend` (`monthlyHistory.map(expenseCents)`). `DashboardKpiRow`: se `balanceTrend != null`, o KPI "Saldo atual" recebe `trend: _Trend(delta: balanceDelta, values: balanceTrend, higherIsBetter: true)` e entra o 5º `KpiTile(label: 'Gasto no mês', cents: monthExpenseCents!, caption: 'até hoje', trend: _Trend(..., higherIsBetter: false))`. `_Trend` (privado) = `Row([DeltaBadge(ratio:, higherIsBetter:), Spacer(), Sparkline(values:)])`. Simples: KPIs idênticos aos de hoje.
aceite:
- Ultra com seed: há `DeltaBadge` e `Sparkline` (2 de cada, ou 1 `DeltaBadge` a menos quando `deltaRatio` é null) e o texto 'Gasto no mês'.
- Simples: nenhum `Sparkline`, nenhum `DeltaBadge`, sem 'Gasto no mês'.
- Teste unitário de `DashboardSummary.of(ledger, ultra: false)` → campos novos todos `null`.
- Testes 390px existentes seguem sem overflow nos dois modos.

### T-062 · Avatar de banco em Cartões e Contas (Ultra) · `done` · deps: T-057 · parallel: yes (com T-061, T-064)
files: `lib/features/cards/presentation/cards_page.dart`, `lib/features/accounts/presentation/accounts_page.dart`, `test/features/cards/cards_page_test.dart`, `test/features/accounts/accounts_page_test.dart`
contrato: SPEC §7.3 tabela Fase 7 "Avatar de banco". Em `_BankSection` (cartões) e `_BankHeader` (contas): no Ultra, `BankAvatar(bankName: bank == _noBank ? '' : bank, size: 20)` + `SizedBox(width: AppSpace.sm)` antes do nome. `_BankHeader` passa a receber `ultra` (o construtor muda dentro do arquivo). Simples: sem avatar.
aceite:
- Ultra com 2 bancos fictícios → 2 `BankAvatar` na página de cartões e na de contas; grupo "sem banco" mostra "?".
- Simples → nenhum `BankAvatar`.
- Testes existentes dos dois arquivos passam.

### T-063 · Ordenação e filtro ativo de transações (lógica) · `done` · deps: — · parallel: yes
files: `lib/features/transactions/presentation/transaction_filters.dart`, `test/features/transactions/transaction_filters_test.dart`
contrato: funções puras no arquivo existente (sem widget novo):
```dart
enum TxSortColumn { date, description, origin, category, value }
typedef TxSort = ({TxSortColumn column, bool ascending});
const TxSort kDefaultTxSort = (column: TxSortColumn.date, ascending: false);
TxSort toggleTxSort(TxSort current, TxSortColumn column);
  // mesma coluna → inverte ascending; coluna nova → ascending = true para description/origin/category, false para date/value
List<Transaction> sortTransactions(
  List<Transaction> rows,
  TxSort sort, {
  required String Function(Transaction t) originName,
  required String Function(Transaction t) categoryName,
}); // nova lista; texto comparado com toLowerCase(); value por amountCents; empate → date desc, depois id asc
```
`TransactionFilter` ganha `bool get hasCriteria` = `origin != null || categoryId != null || kinds.isNotEmpty || query.trim().isNotEmpty || !showPlanned`.
aceite:
- `sortTransactions` com `kDefaultTxSort` dá a mesma ordem de `visibleTransactions` para transações de datas distintas.
- Cada coluna em asc e desc ordena corretamente (3 transações); empate de valor resolvido por data desc; a lista de entrada não é alterada.
- `toggleTxSort(kDefaultTxSort, date)` → asc; `toggleTxSort(kDefaultTxSort, description)` → `(description, true)`; `toggleTxSort(.., value)` vindo de outra coluna → `(value, false)`.
- `const TransactionFilter().hasCriteria == false`; `query: '  '` → false; `categoryId: 'x'` → true; `showPlanned: false` → true.

### T-064 · Transações: cabeçalho ordenável (Ultra) e estado vazio com ação · `done` · deps: T-057, T-063 · parallel: yes (com T-061, T-062)
files: `lib/features/transactions/presentation/transaction_row.dart`, `lib/features/transactions/presentation/transactions_page.dart`, `test/features/transactions/transactions_page_test.dart`
contrato: SPEC §7.3 tabela Fase 7. `TransactionTableHeader({required bool ultra, TxSort? sort, ValueChanged<TxSortColumn>? onSort})`: cada rótulo vira `SortableHeaderLabel(label:, active: sort?.column == col, ascending: sort?.ascending ?? false, onTap: onSort == null ? null : () => onSort(col))`; Valor com `alignEnd: true`. Simples passa só `ultra: false` (estático). `_TransactionsPageState`: `TxSort _sort = kDefaultTxSort` e `int _filterEpoch = 0`; Ultra → `rows = sortTransactions(visibleTransactions(...), _sort, originName: <mesmo texto da coluna Conta/Cartão>, categoryName: (t) => ledger.categoriesById[t.categoryId]?.name ?? '')`; cabeçalho Ultra recebe `sort: _sort, onSort: (c) => setState(() => _sort = toggleTxSort(_sort, c))`. Estado vazio: `action` = `FilledButton.icon('Nova transação', onPressed: () => showTransactionForm(context))`; Ultra com `_filter.hasCriteria` → em vez disso `Wrap` com esse botão + `OutlinedButton('Limpar filtros')` que faz `setState(() { _filter = const TransactionFilter(); _filterEpoch++; })`; `TransactionFilterBar` recebe `key: ValueKey(_filterEpoch)` (recria campos com valores iniciais). `_TransactionTable` recebe o `action` pronto. Ordenação ocorre só sobre as linhas do mês já filtradas (barato); nada novo no Ledger.
aceite:
- Ultra: tocar "Valor" duas vezes alterna a ordem das linhas (primeira linha muda conforme `amountCents`); tocar "Descrição" ordena A→Z.
- Simples: tocar "Valor" não muda a ordem; não há `InkWell` nos rótulos do cabeçalho.
- Mês vazio → botão "Nova transação" abre o form (encontrar 'Cancelar'). Ultra com busca sem resultado → "Limpar filtros" restaura as linhas e esvazia o campo de busca.
- Testes existentes do arquivo passam.

### T-065 · Estados vazios com ação: Recorrentes e Categorias · `done` · deps: — · parallel: yes
files: `lib/features/recurring/presentation/recurring_page.dart`, `lib/features/categories/presentation/categories_page.dart`, `test/features/recurring/recurring_page_test.dart`, `test/features/categories/categories_page_test.dart`
contrato: SPEC §7.3 tabela Fase 7 "Estado vazio com ação". `RecurringPage`: `EmptyState(..., action: FilledButton.icon(icon: Icon(Icons.add), label: Text('Nova recorrência'), onPressed: () => showRecurringForm(context)))` (deixa de ser `const`). `CategoriesPage`: `EmptyState(..., action: FilledButton.icon(..., label: Text('Nova categoria'), onPressed: () => showCategoryForm(context, kind: _kind)))`. Ambos os modos.
aceite:
- Sem recorrências → botão 'Nova recorrência' no estado vazio abre o form (há 2 botões com o texto: o do cabeçalho e o do vazio; tocar o do `EmptyState` via `find.descendant`).
- Sem categorias do tipo ativo → botão 'Nova categoria' no estado vazio abre o form com o tipo da aba.
- Testes existentes passam.

### T-066 · Tooltip rico no gráfico de saldo diário · `done` · deps: T-051 · parallel: yes (com T-052, T-053, T-056, T-059, T-060)
files: `lib/features/forecast/presentation/forecast_chart.dart`, `lib/features/forecast/presentation/forecast_page.dart`, `test/features/forecast/forecast_chart_test.dart`
contrato: SPEC §7.3 tabela Fase 7 "Tooltip rico". `ForecastDailyChart({super.key, required List<DailyBalance> daily, List<ForecastEvent> events = const [], bool hideValues = false})`. Função pública pura no mesmo arquivo: `({int income, int expense, int count}) dayFlow(List<ForecastEvent> events, DateTime day)` — eventos com mesma data (ano/mês/dia), ignorando `ForecastEventKind.transfer`; `income` = soma dos `amountCents > 0`, `expense` = soma dos `-amountCents` dos `< 0`, `count` = eventos considerados. Calculada só dentro de `getTooltipItems` (no toque), nunca no `build`. Texto do tooltip: `formatDate(dia)`, `'Saldo ${formatMoney(saldo, hidden: hideValues)}'`, `'Entradas ...'` se income > 0, `'Saídas ...'` se expense > 0, `'$count eventos'` (ou `'1 evento'`) se count > 0, uma linha cada. `getTooltipColor: (_) => colors.surface`, `tooltipBorder: BorderSide(color: colors.border)`. `ForecastPage` passa `events: forecast.events, hideValues: s.settings.value.hideValues`.
aceite:
- `dayFlow`: dia com receita 1000, despesa -300, despesa -200 e transferência → `(income: 1000, expense: 500, count: 3)`; dia sem eventos → `(0, 0, 0)`.
- Widget: `ForecastDailyChart(daily: ..., events: ...)` monta sem exceção; testes existentes do arquivo passam.

### T-067 · Documentação da Fase 7 · `done` · deps: T-050..T-066 · parallel: no
files: `CONTEXT.md`, `ROADMAP.md`, `docs/BACKLOG.md`
contrato: CONTEXT §4 (árvore: `boot_screen.dart`, `app_text.dart`, widgets novos, `monthly_history.dart`; linha do `home_shell.dart` sem drawer), §5 (tabela com os recursos da Fase 7), §8 (testes novos e total), §10 (commit da fase), §11 (status). ROADMAP: Fase 7 em "v3". BACKLOG: tarefas T-050..T-066 `done`.
aceite: nenhuma menção a drawer como existente; total de testes igual ao de `flutter test`; `bash tool/check.sh` → `CHECK OK`.
