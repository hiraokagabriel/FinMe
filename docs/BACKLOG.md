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

## Fase 8 — Importação, regras e categorização automática

> Origem: `docs/V3_DIRECTION.md` (Importação). Contratos: SPEC §3.5 (boxes e backup), §3.7, §4.4 (campos novos), §4.6–4.8, §5.11–5.16, §6.1–6.3, §7.3 "Importação, regras e categorização (Fase 8)".
> Domínio puro primeiro (`core/utils` e `features/*/domain` sem `package:flutter`), com testes fortes; UI depois.
> Decisões fechadas: Importar = item 5 da sidebar (9 páginas) + botão em Transações; Regras e Dicionário = seções da página Importar só no Ultra; prévia enxuta no Simples.
> Ondas (tarefas da mesma onda têm arquivos disjuntos): **A** T-070, T-071, T-072 · **B** T-073, T-074, T-075, T-076, T-077, T-078, T-079 · **C** T-080, T-085 · **D** T-081, T-082 · **E** T-083, T-084, T-086, T-087, T-088 · **F** T-089 · **G** T-090 · **H** T-091 · **I** T-092.
> Fixtures: só texto fictício (bancos "Alfa"/"Beta", lojas "Exemplo"). Testes leem com `File('test/fixtures/import/<nome>').readAsBytesSync()`.
> Datas nos testes: `DateTime(2026, 11, 14)` como "hoje", salvo indicação.

### T-070 · Normalização de texto (core) · `done` · deps: — · parallel: yes
files: `lib/core/utils/text_normalize.dart` (novo), `test/core/text_normalize_test.dart` (novo)
contrato: SPEC §3.7 inteiro (`foldText`, `normalizeDescription`, `descriptionTokens`, `jaccard`, `similarDescriptions`, `kStopTokens`, `kUfTokens` com as 27 UFs + `BR`/`BRA`/`BRASIL`, `kCitySuffixes`). Dart puro; regex pré-compiladas em `final` de topo.
aceite:
- Os 8 exemplos de `normalizeDescription` do SPEC §3.7.
- `foldText('  Ação  São\tJoão ') == 'ACAO SAO JOAO'`; `foldText('café') == 'CAFE'`; pontuação mantida: `foldText('apple.com/bill') == 'APPLE.COM/BILL'`.
- `descriptionTokens('PAG LOJA DE X EXEMPLO') == {'LOJA', 'EXEMPLO'}`.
- `jaccard({'A','B'}, {'B','C'}) == 1/3`; `jaccard({}, {}) == 0.0`.
- `similarDescriptions('IFOOD*RESTAURANTE X', 'IFOOD RESTAURANTE X 12/11') == true`; `('LOJA', 'LOJA EXEMPLO') == true` (contida, 4 chars); `('UBER TRIP', '99 POP') == false`; `('123', '456') == false` (chaves vazias).

### T-071 · `Transaction`: `externalId` e `importedDescription` · `done` · deps: — · parallel: yes
files: `lib/features/transactions/domain/transaction.dart`, `test/features/transaction_import_fields_test.dart` (novo)
contrato: SPEC §4.4 (bloco Fase 8). Dois campos `String?` no construtor (opcionais), `fromMap`, `toMap` (só grava se não nulo), `copyWith` com `Object? x = _keep`, `==`/`hashCode`.
aceite:
- Round-trip `fromMap(toMap(t)) == t` com os dois campos preenchidos.
- `toMap()` de transação sem os campos não tem as chaves `externalId`/`importedDescription`; `fromMap` de mapa antigo → ambos `null`.
- `t.copyWith(externalId: null).externalId == null`; `t.copyWith()` mantém; transações que diferem só em `importedDescription` não são `==`.
- Testes existentes (`entities_test`, `copy_with_clear_test`) passam.

### T-072 · `ImportedLine` e `ImportProfile` · `done` · deps: — · parallel: yes
files: `lib/features/importing/domain/imported_line.dart` (novo), `lib/features/importing/domain/import_profile.dart` (novo), `test/features/importing/import_profile_test.dart` (novo)
contrato: SPEC §5.11 (classes `ImportedLine`, `ImportLineError`, `ImportParseResult`) e §4.7 inteiro (enums `ImportFormat`, `DateOrder`, `DecimalMark`, `InstallmentDateMode`; `ImportProfile` com `mappingError`, `learnBankCategories`, `copyWith` com `_keep`). Enums via `enumByName`.
aceite:
- Round-trip `fromMap(toMap(p)) == p` com `categoryMap: {'SUPERMERCADO': 'cat_mercado'}` e débito/crédito preenchidos.
- `ImportProfile.fromMap({'id': 'p', 'name': 'X'})` tem todos os padrões do SPEC (`delimiter ';'`, `skipRows 1`, `amountColumn 2`, `dmy`, `comma`, `posting`, mapa vazio).
- `mappingError`: sem destino → `'Escolha a conta ou o cartão'`; com `accountId` e `cardId` → idem; `amountColumn: 2, debitColumn: 3` → `'Use valor único ou débito/crédito'`; `amountColumn: null` sem débito/crédito → idem; `descriptionColumn: 0` (= `dateColumn`) → `'Colunas repetidas ou inválidas'`; `delimiter: ';;'` → `'Separador inválido'`; `skipRows: -1` → `'Linhas a pular inválidas'`; válido → `null`; `format: ofx` com destino e colunas repetidas → `null`.
- `learnBankCategories({'A': 'x', 'SUPERMERCADO': 'y'})` sobre mapa `{'SUPERMERCADO': 'cat_mercado'}` → `{'SUPERMERCADO': 'cat_mercado', 'A': 'x'}`.
- `copyWith(amountColumn: null, debitColumn: 3)` limpa um e define o outro.

### T-073 · Parcelas em linhas importadas · `done` · deps: T-070, T-072 · parallel: yes
files: `lib/features/importing/domain/import_installments.dart` (novo), `test/features/importing/import_installments_test.dart` (novo)
contrato: SPEC §5.12 inteiro (`InstallmentMark`, `detectInstallment`, `importedInstallmentDates`). Mês de fatura só por `invoiceDueMonth`, `installmentDueMonth`, `invoiceClosingDate` (`invoice_cycle.dart`) e datas por `addMonthsClamped`.
aceite:
- `detectInstallment`: todos os exemplos do SPEC §5.12, mais `'Loja Exemplo - Parcela 2/6'` → (2,6) e `'PARC.03/10 LOJA'` → (3,10).
- `importedInstallmentDates`: os 5 exemplos do SPEC §5.12 (fecha 5/vence 12 posting e purchase; fecha 31/vence 7 com ajuste para 27/02/2027; histórico de ciclo do §5.1 → faturas nov/jan/fev; conta corrente "3/4"). Para cartão, verificar também `invoiceDueMonth(d_i, card)` de cada data.
- `index == count` → lista de 1 item (a própria linha).

### T-074 · Parser CSV · `done` · deps: T-072 · parallel: yes
files: `lib/features/importing/domain/csv_import.dart` (novo), `test/features/importing/csv_import_test.dart` (novo), `test/fixtures/import/extrato_conta.csv` (novo), `test/fixtures/import/fatura_cartao.csv` (novo)
contrato: SPEC §5.11 bloco CSV (`decodeText`, `guessDelimiter`, `readCsv`, `parseAmountCell`, `parseDateCell`, `parseCsvLines`). Usa `package:csv` e `dart:convert`; sem `double`.
fixture `extrato_conta.csv` (UTF-8, exato):
```
Extrato fictício - Banco Alfa;;;
Data;Histórico;Valor;Categoria
05/11/2026;PADARIA PAO BOM CURITIBA PR;-12,50;Alimentação
06/11/2026;"MERCADO EXEMPLO; FILIAL 2";-1.234,56;Supermercado
07/11/2026;SALARIO EMPRESA FICTICIA;5.000,00;
08/11/2026;PAGTO FATURA CARTAO;-800,00;
31/02/2026;LINHA COM DATA INVALIDA;-1,00;
09/11/2026;BOLETO CONDOMINIO;abc;
10/11/2026;LOJA EXEMPLO PARC 03/10;-150,00;Compras
```
fixture `fatura_cartao.csv` (exato):
```
date,title,amount
2026-11-02,"IFOOD *RESTAURANTE, CENTRO",45.90
2026-11-03,UBER *TRIP 8X7Y2 SAO PAULO BR,23.15
2026-11-04,Loja Exemplo - Parcela 2/6,99.99
2026-11-05,Pagamento recebido,-1500.00
2026-11-06,ESTORNO LOJA EXEMPLO,-10.00
```
aceite:
- Todos os exemplos de `parseAmountCell` do SPEC; `parseDateCell('05/11/2026', dmy)`, `('11/05/2026', mdy)`, `('2026-11-05 10:30', ymd)`, `('2026-11-05T10:30:00', ymd)`, `('05.11.26', dmy)` → 05/11/2026; `('31/02/2026', dmy)` e `('xx', dmy)` → `null`.
- `decodeText(latin1.encode('Descrição;Café')) == 'Descrição;Café'`; `decodeText([0xEF, 0xBB, 0xBF, ...utf8.encode('Olá')]) == 'Olá'`.
- `guessDelimiter`: `extrato_conta.csv` → `';'`; `fatura_cartao.csv` → `','`; `'a\tb\tc\n1\t2\t3'` → `'\t'`; `''` → `';'`.
- `extrato_conta.csv` com perfil (`;`, `skipRows: 2`, data 0, desc 1, valor 2, categoria 3, `dmy`, `comma`): 5 linhas (rows 3,4,5,6,9) com valores `-1250, -123456, 500000, -80000, -15000`; row 4 descrição `'MERCADO EXEMPLO; FILIAL 2'`; row 3 `bankCategory 'Alimentação'`, row 5 `bankCategory null`; erros `(7, 'Data inválida')` e `(8, 'Valor inválido')`. O mesmo texto com CRLF (`replaceAll('\n', '\r\n')`) dá o mesmo resultado.
- `fatura_cartao.csv` com perfil (`,`, `skipRows: 1`, `ymd`, `dot`, `invertSign: true`): valores `-4590, -2315, -9999, 150000, 1000`; row 2 descrição `'IFOOD *RESTAURANTE, CENTRO'`.
- Débito/crédito (inline): `'Data;Descricao;Debito;Credito\n01/11/2026;TARIFA PACOTE;29,90;\n02/11/2026;PIX RECEBIDO FICTICIO;;150,00\n03/11/2026;AJUSTE;10,00;25,00\n04/11/2026;VAZIO;;'` com débito 2, crédito 3, sem `amountColumn` → `-2990, 15000, 1500` e erro `(5, 'Valor inválido')`.
- Linha curta (`'05/11/2026;SO DUAS'` com valor na coluna 2) → `'Coluna ausente'`; valor `'0,00'` → `'Valor zero'`.

### T-075 · Parser OFX · `done` · deps: T-070, T-072 · parallel: yes
files: `lib/features/importing/domain/ofx_parser.dart` (novo), `test/features/importing/ofx_parser_test.dart` (novo), `test/fixtures/import/extrato_conta.ofx` (novo), `test/fixtures/import/fatura_cartao.ofx` (novo)
contrato: SPEC §5.11 bloco OFX (`OfxStatement`, `parseOfx`, regras 1–7). Sem dependência nova, sem `double`. Testes decodificam com `latin1.decode` (fixtures são ASCII; não depende de T-074).
fixture `extrato_conta.ofx` (SGML, sem tags de fechamento nos elementos nem em `STMTTRN`; exato):
```
OFXHEADER:100
DATA:OFXSGML
VERSION:102
SECURITY:NONE
ENCODING:USASCII
CHARSET:1252
COMPRESSION:NONE
OLDFILEUID:NONE
NEWFILEUID:NONE

<OFX>
<SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO</STATUS><DTSERVER>20261110120000[-3:BRT]<LANGUAGE>POR</SONRS></SIGNONMSGSRSV1>
<BANKMSGSRSV1>
<STMTTRNRS>
<TRNUID>1
<STMTRS>
<CURDEF>BRL
<BANKACCTFROM>
<BANKID>0000
<ACCTID>12345-6
<ACCTTYPE>CHECKING
</BANKACCTFROM>
<BANKTRANLIST>
<DTSTART>20261101
<DTEND>20261110
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261103120000[-3:BRT]
<TRNAMT>-35.90
<FITID>FIT0001
<NAME>FARMACIA EXEMPLO
<MEMO>FARMACIA EXEMPLO
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20261105
<TRNAMT>2500,00
<FITID>FIT0002
<MEMO>TED RECEBIDA FICTICIA
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261106
<TRNAMT>-120.00
<FITID>FIT0003
<NAME>CASA &amp; CIA
<MEMO>COMPRA CARTAO DEBITO
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>2026XX07
<TRNAMT>-1.00
<FITID>FIT0004
<NAME>DATA RUIM
</BANKTRANLIST>
<LEDGERBAL><BALAMT>1000.00<DTASOF>20261110</LEDGERBAL>
</STMTRS>
</STMTTRNRS>
</BANKMSGSRSV1>
</OFX>
```
fixture `fatura_cartao.ofx` (XML; exato):
```
<?xml version="1.0" encoding="UTF-8"?>
<?OFX OFXHEADER="200" VERSION="211" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE"?>
<OFX>
  <CREDITCARDMSGSRSV1>
    <CCSTMTTRNRS>
      <CCSTMTRS>
        <CURDEF>BRL</CURDEF>
        <CCACCTFROM><ACCTID>9999</ACCTID></CCACCTFROM>
        <BANKTRANLIST>
          <STMTTRN>
            <TRNTYPE>DEBIT</TRNTYPE>
            <DTPOSTED>20261102000000[-3:BRT]</DTPOSTED>
            <TRNAMT>-59.90</TRNAMT>
            <FITID>CC-1</FITID>
            <MEMO>NETFLIX.COM</MEMO>
          </STMTTRN>
          <STMTTRN>
            <TRNTYPE>DEBIT</TRNTYPE>
            <DTPOSTED>20261108</DTPOSTED>
            <TRNAMT>-200.00</TRNAMT>
            <FITID>CC-2</FITID>
            <NAME>LOJA EXEMPLO PARC 03/10</NAME>
          </STMTTRN>
          <STMTTRN>
            <TRNTYPE>CREDIT</TRNTYPE>
            <DTPOSTED>20261109</DTPOSTED>
            <TRNAMT>1.500,00</TRNAMT>
            <FITID>CC-3</FITID>
            <NAME>PAGAMENTO RECEBIDO</NAME>
          </STMTTRN>
        </BANKTRANLIST>
      </CCSTMTRS>
    </CCSTMTTRNRS>
  </CREDITCARDMSGSRSV1>
</OFX>
```
aceite:
- `extrato_conta.ofx`: `isCreditCard false`, `accountId '12345-6'`; 3 linhas: (row 1, 03/11/2026, `-3590`, `'FARMACIA EXEMPLO'`, fitid `'FIT0001'`), (row 2, 05/11/2026, `250000`, `'TED RECEBIDA FICTICIA'`), (row 3, 06/11/2026, `-12000`, `'CASA & CIA COMPRA CARTAO DEBITO'`); erro `(4, 'Data inválida')`.
- `fatura_cartao.ofx`: `isCreditCard true`, `accountId '9999'`; valores `-5990, -20000, 150000`; descrições `'NETFLIX.COM'`, `'LOJA EXEMPLO PARC 03/10'`, `'PAGAMENTO RECEBIDO'`; fitids `CC-1..CC-3`.
- A fixture SGML em minúsculas (`text.toLowerCase()`) dá as mesmas datas, valores e fitids.
- `parseOfx('lixo')` lança `FormatException`; bloco com `<TRNAMT>0.00` → erro `'Valor zero'`; bloco sem NAME/MEMO → `'Descrição vazia'`.

### T-076 · `TransactionRule` e motor de regras · `done` · deps: T-070, T-071 · parallel: yes
files: `lib/features/rules/domain/transaction_rule.dart` (novo), `lib/features/rules/domain/rule_engine.dart` (novo), `test/features/rules/rule_engine_test.dart` (novo)
contrato: SPEC §4.6 e §5.14 inteiros.
aceite:
- Entidade: round-trip; `fromMap({'id': 'r', 'pattern': 'x'})` → `contains`, `priority 0`, `active true`; `copyWith(categoryId: null)` limpa.
- `CompiledRule.matches`: contains `'farmácia'` casa `'FARMACIA SAO JOAO'`; startsWith `'uber'` casa `'UBER *TRIP'` e não `'PAG UBER'`; regex `'^uber\s'` casa `'Uber trip'`; regex `'('` → `isValidRulePattern == false` e nunca casa (sem exceção); pattern `'  '` nunca casa.
- `compileRules`: exclui inativas; ordena priority asc e empate por id (`b` prio 0, `a` prio 0, `c` prio −1 → c, a, b).
- `reorderRules([r3, r1, r2])` → priorities 0, 1, 2 na ordem dada.
- `matchingTransactions` ignora transfer/invoicePayment e inclui regra inativa.
- `reapplyRules`: despesa sem categoria recebe a da regra; despesa já categorizada fica igual sem `overwriteCategory` e muda com ele; regra com categoria de receita não toca despesa; renomear grava `description = renameTo` e `importedDescription` = descrição antiga; chamar de novo sobre o resultado aplicado → `[]` (idempotente); retorna só as que mudam.

### T-077 · Dicionário de estabelecimentos (domínio) · `done` · deps: T-070 · parallel: yes
files: `lib/features/importing/domain/merchant_dictionary.dart` (novo), `test/features/importing/merchant_dictionary_test.dart` (novo)
contrato: SPEC §4.8 e §5.13 bloco `merchant_dictionary.dart` + lista "Dicionário embutido" (copiar exatamente, na ordem do SPEC; categorias por nome: `'Transporte'`, `'Combustível'`, `'Alimentação'`, `'Mercado'`, `'Saúde'`, `'Assinaturas'`, `'Compras'`, `'Contas e serviços'`, `'Moradia'`, `'Educação'`, `'Lazer'`, `'Viagem'`, `'Salário'`, `'Rendimentos'`).
aceite:
- `dictionaryPatternMatches('DROGA', 'DROGASIL EXEMPLO')` true; `('RAIA', 'DROGA RAIA')` true; `('99', '1990 LOJA')` false; `('99APP', '99APP *CORRIDA')` true; `('MERCADO', 'SUPERMERCADO X')` false.
- `resolveCategoryByName` contra `defaultCategories()` (de `lib/app/seed.dart`; o teste pode importar): `'alimentacao'` → `'cat_alimentacao'`; `'Combustível'` → `'cat_transporte'` (fallback); `'Inexistente'` → null.
- `defaultDictionary()`: tamanho == `kDefaultDictionary.length`; ids únicos começando com `'dict_'`; todo `pattern == foldText(pattern)`; todo `categoryName` resolve contra `defaultCategories()`.
- Round-trip de `DictionaryEntry`.

### T-078 · Histórico de categorias · `done` · deps: T-070, T-071 · parallel: yes
files: `lib/features/importing/domain/category_history.dart` (novo), `test/features/importing/category_history_test.dart` (novo)
contrato: SPEC §5.13 bloco `CategoryHistory` (build, `exact`, `similar`, `empty`, limites 500/300). Assunto = `t.importedDescription ?? t.description` (igual a `ruleSubject`, sem importar `rules/`).
aceite:
- 3× `'PADARIA PAO BOM 01'` em `cat_alim` + 1× em `cat_merc` → `exact('PADARIA PAO BOM') == (categoryId: 'cat_alim', share: 0.75)`.
- Empate 1×1 → vence a categoria da transação mais recente.
- Transfer, invoicePayment e sem categoria são ignorados; descrição só com dígitos não cria chave; `importedDescription` tem preferência sobre `description`.
- `similar('PADARIA PAO BOM FILIAL')` → `cat_alim`, score 0.75; `similar('OUTRA COISA')` → null; `threshold: 0.8` → null.
- Token comum a 501 chaves (gerar `'LOJA ' + 3 letras` de `AAA` em diante) é ignorado: `similar('LOJA ZZZ')` → null.
- `CategoryHistory.empty.exact('X') == null`.

### T-079 · Duplicatas e casamentos (matcher) · `done` · deps: T-070, T-071, T-072 · parallel: yes
files: `lib/features/importing/domain/import_matcher.dart` (novo), `test/features/importing/import_matcher_test.dart` (novo)
contrato: SPEC §5.15 inteiro. Parâmetro `installment` tipado como `({int index, int count})?` (record estrutural; não importa `import_installments.dart`). Dias por `DateTime.utc`. Assunto = `t.importedDescription ?? t.description`.
aceite (existentes: e1 despesa paga cartão C 10000 em 05/11/2026 `'IFOOD*RESTAURANTE X'` externalId `'F1'`; e2 despesa `planned` conta A 35000 em 10/11 `'Boleto condomínio'`; e3 despesa cartão C 15000 em 08/12 `'LOJA EXEMPLO PARC 03/10'` grupo g 3/10; e4 despesa paga conta A 5990 em 01/06 `'NETFLIX.COM'`; um matcher novo por caso, salvo indicação):
- Linha cartão C fitid `'F1'` → `fitidDuplicate`, `duplicateOf == e1`.
- Linha cartão C 06/11 `-10000` `'IFOOD *RESTAURANTE X 12/11'` → `probableDuplicate`; com data 08/11 → só `sameNameAmount`.
- Linha conta A `-35000` em 13/11 `'PAGTO BOLETO 123'` → `plannedMatch == e2`, sem flag; em 16/11 → sem casamento.
- Linha cartão C `-15000` 08/11 `'LOJA EXEMPLO PARC 03/10'` com `installment (3,10)` → `existingInstallment`, `duplicateOf == e3`.
- Linha conta B `-5990` 01/11 `'NETFLIX.COM'` → só `sameNameAmount`.
- `'PAGTO FATURA CARTAO'` e `'PAGAMENTO RECEBIDO'` → `invoicePaymentLike`.
- Mesmo matcher, duas linhas iguais (06/11 `-10000` IFOOD sem fitid) → 1ª `probableDuplicate`, 2ª sem `probableDuplicate` (e1 consumida).
- Linha `+10000` (receita) cartão C 05/11 IFOOD sem fitid → não é `probableDuplicate` (tipo diferente).
- Existentes transfer/invoicePayment nunca casam.

### T-080 · Categorizador em cascata · `done` · deps: T-076, T-077, T-078 · parallel: yes (com T-085)
files: `lib/features/importing/domain/categorizer.dart` (novo), `test/features/importing/categorizer_test.dart` (novo)
contrato: SPEC §5.13 blocos `categorizer.dart`, "Categoria permitida" e "Cascata" (passos 1–5, confianças exatas), `confidenceLabel`.
aceite (categorias: `defaultCategories()`; dicionário: `defaultDictionary()`):
- Regra contains `'IFOOD'` → `cat_alimentacao` (prio 0) e regra regex `'^UBER'` → `cat_transporte` com `renameTo 'Uber'` (prio 1): `'UBER *TRIP'` → `(cat_transporte, rule, 1.0, ruleId, renamedDescription 'Uber')`.
- Regra só com `renameTo` casa; categoria vem do dicionário e `renamedDescription` é mantido.
- Regra com `cat_salario` numa despesa é pulada (cai no passo seguinte).
- Banco: `bankCategoryMap {'SUPERMERCADO': 'cat_mercado'}` + `bankCategory 'Supermercado'` → `bank` 0.9; `bankCategory 'mercado'` sem mapa → `bank` 0.7; `bankCategory 'Xyz'` → segue a cascata.
- Histórico: 3×`cat_alimentacao` + 1×`cat_mercado` em `'PADARIA PAO BOM 01'` → `history`, confiança 0.8; `'PADARIA PAO BOM FILIAL'` (histórico só com `cat_alimentacao`) → `history`, 0.45.
- Dicionário: `'MERCADO LIVRE*VENDEDOR'` → `cat_compras`; `'MERCADO DO BAIRRO'` → `cat_mercado`; `'POSTO EXEMPLO'` → `cat_transporte`; `'AMAZON PRIME'` → `cat_assinaturas`; `'SALARIO EMPRESA'` com `isIncome: true` → `cat_salario`, com `isIncome: false` → sem categoria.
- `'XPTO QWERTY'` → categoryId null, source null, confiança 0.
- `confidenceLabel(0.8) == 'alta'`, `(0.79) == 'média'`, `(0.5) == 'média'`, `(0.49) == 'baixa'`.

### T-081 · Sessão de prévia e plano de importação · `done` · deps: T-073, T-079, T-080 · parallel: yes (com T-082)
files: `lib/features/importing/domain/import_session.dart` (novo), `test/features/importing/import_session_test.dart` (novo)
contrato: SPEC §5.16 inteiro (`ImportTarget`, `ImportRow`, `ImportSession`, `ImportPlan`, `buildImportPlan`, `learnedBankCategories`). Testes usam `idGenerator` determinístico (`'id1'`, `'id2'`, …).
aceite:
- Linhas válidas do `extrato_conta.csv` (montadas à mão como `ImportedLine`, sem ler arquivo) com destino conta A e sem transações existentes: `PAGTO FATURA CARTAO` começa desmarcada (`invoicePaymentLike`); demais marcadas; `LOJA EXEMPLO PARC 03/10` tem `installment (3,10)` e `createInstallments true`; `summary == (create: 4, confirm: 0, skipped: 1, futureInstallments: 7)`.
- `setCategory(i, 'cat_x')` marca `categoryEdited`; `recategorize` com categorizador novo (regra nova) muda as linhas não editadas e preserva a editada.
- `setAllIncluded(false)` → `summary.create == 0`; `uncategorizedIndices` lista só as sem categoria.
- Plano conta A: linha com `plannedMatch` → 1 item em `update` com `status paid`, `date` da linha, descrição e valor do provisionado; parcela 3/10 → 8 transações `'<g>_3'..'<g>_10'` com o mesmo `installmentGroupId`, a de índice 3 `paid` com `importedDescription`, 4..10 `planned`, todas com o valor da linha; linha com data > today → `planned`; linha desmarcada não aparece.
- Plano cartão de crédito (fecha 5/vence 12), linha 08/11/2026 `-20000` `'LOJA EXEMPLO PARC 03/10'` fitid `'CC-2'` → 8 transações com `cardId`, só a 1ª com `externalId 'CC-2'`; `InvoiceService.build` com elas põe a parcela 3 em `2026-12` e a 10 em `2027-07`.
- `setCreateInstallments(i, false)` → transação única sem campos de parcela.
- `learnedBankCategories` devolve `foldText(bankCategory) → categoryId` só das incluídas.
- Desempenho: 2.000 linhas (descrições variadas, 10% repetindo existentes) contra 10.000 transações existentes em 3 origens → `ImportSession.build` + `buildImportPlan` < 2 s (`Stopwatch`).

### T-082 · Persistência e Ledger da Fase 8 · `done` · deps: T-072, T-076, T-077, T-080 · parallel: yes (com T-081)
files: `lib/app/bootstrap.dart`, `lib/app/app_scope.dart`, `lib/app/ledger.dart`, `test/app/ledger_import_test.dart` (novo)
contrato: SPEC §3.5 (boxes `fm_rules`, `fm_import_profiles`, `fm_dictionary`; semear dicionário vazio com `defaultDictionary()`), §6.1 (3 repositórios novos obrigatórios em `AppServices`), §6.2 (`Ledger` com `rules`/`dictionary` opcionais e `Categorizer get categorizer` memoizado; `_categorizer` zerado em `_clearCache`; repositórios presentes entram em `_sources`).
aceite:
- `bootstrap(storeFactory: memória)` → `dictionary.all.length == kDefaultDictionary.length`, `rules` e `importProfiles` vazios; segundo `bootstrap` sobre os mesmos stores não duplica o dicionário.
- `identical(ledger.categorizer, ledger.categorizer)`; após `rules.upsert(TransactionRule(id: 'r', pattern: 'XPTO', categoryId: 'cat_lazer'))` o categorizador é outro e `categorize('XPTO 1', isIncome: false).categoryId == 'cat_lazer'`.
- Após `transactions.upsert` de despesa `'PADARIA PAO BOM'` em `cat_alimentacao`, `categorize('PADARIA PAO BOM 2', isIncome: false).source == SuggestionSource.history`.
- `test/app/ledger_test.dart` (constrói `Ledger` sem os repositórios novos) passa sem mudança.

### T-083 · Backup e "apagar dados" cobrem a Fase 8 · `done` · deps: T-082 · parallel: yes
files: `lib/core/services/backup_service.dart`, `lib/features/settings/presentation/settings_page.dart`, `test/core/backup_service_test.dart`, `test/features/settings/settings_page_test.dart`
contrato: SPEC §3.5 "Backup e as boxes da Fase 8" (chaves `rules`, `importProfiles`, `dictionary`; versão 1; ausência tolerada; perfil com destino ausente descartado; regra com categoria ausente → `categoryId null`; retrato e restauração incluem as 3) e "Apagar todos os dados".
aceite:
- Export → import em app vazio devolve regras, perfis e dicionário editado iguais.
- Backup sem as 3 chaves → regras e perfis vazios, dicionário == `defaultDictionary()`.
- Perfil com `accountId` inexistente no backup some; regra com `categoryId` inexistente fica `null`.
- Falha na gravação (store que lança uma vez em `fm_rules`) restaura regras, perfis e dicionário anteriores (mesmo padrão do teste de rollback existente).
- Ajustes Ultra → "Apagar todos os dados" confirmado → regras e perfis vazios, dicionário volta ao padrão.

### T-084 · Sugestão de categoria no lançamento manual · `done` · deps: T-082 · parallel: yes
files: `lib/features/transactions/presentation/transaction_form.dart`, `test/features/transactions/transaction_form_test.dart`
contrato: SPEC §7.3 tabela Fase 8, linha "Sugestão no lançamento manual". `bool _categoryTouched` = `initial?.categoryId != null`; `CategorizationResult? _suggestion`. `onChanged` do campo Descrição: se `!_categoryTouched` e tipo expense/income → `r = AppScope.of(context).ledger.categorizer.categorize(texto, isIncome: _type == TransactionType.income)`; se `r.categoryId` está em `_categoriesFor(s)` → `setState(() { _categoryId = r.categoryId; _suggestion = r; })`; senão `_suggestion = null` (mantém a categoria atual). `onChanged` do dropdown de categoria → `_categoryTouched = true`, `_suggestion = null`. Dropdown com `key: ValueKey('form-categoria-${_type.name}-$_categoryId')` (recria com o novo `initialValue`) e `helperText` `'Sugerida por regra'` / `'Sugerida pelo banco'` / `'Sugerida pelo histórico'` / `'Sugerida pelo dicionário'` quando `_suggestion?.source != null`. Não renomeia a descrição.
aceite:
- Nova despesa: digitar `'IFOOD PEDIDO'` seleciona "Alimentação" e mostra 'Sugerida pelo dicionário'.
- Escolher "Lazer" manualmente e depois digitar `'UBER'` mantém "Lazer".
- Editar transação existente com categoria e mudar a descrição não troca a categoria.
- Nova receita `'SALARIO EMPRESA'` → "Salário".
- Testes existentes passam.

### T-085 · Assistente de mapeamento CSV e destino OFX · `done` · deps: T-074 · parallel: yes (com T-080)
files: `lib/features/importing/presentation/import_mapping_dialog.dart` (novo), `test/features/importing/import_mapping_dialog_test.dart` (novo)
contrato: SPEC §7.3 tabela Fase 8, linha "Assistente CSV".
```dart
typedef ImportSetup = ({ImportProfile profile, bool save});
Future<ImportSetup?> showImportMappingDialog(BuildContext context, {required String text, ImportProfile? initial});
  // initial null → ImportProfile(id: newId(), name: '', delimiter: guessDelimiter(text)). text '' = editar perfil sem amostra.
Future<ImportSetup?> showImportTargetDialog(BuildContext context, {required bool suggestCard, ImportProfile? initial});
  // OFX: destino (contas e cartões ativos), "Inverter sinal", "Salvar como perfil" + nome; profile.format = ofx
```
`showDialog` com largura máx. 720 (mapeamento) / 520 (destino). Estado: `rows = readCsv(text, delimiter: ...)` recalculado só quando o separador muda; prévia = `parseCsvLines(rows.take(skipRows + 5).toList(), perfil)` mostrando data (`formatDate`), descrição e valor (`MoneyText` com sinal) por linha, ou a mensagem de erro da linha. Destino: `DropdownButtonFormField<String>` (`initialValue`) com itens `'acc:<id>'` ("Conta · nome") e `'card:<id>'` ("Cartão · nome"), só não arquivados (`AppScope.of(context)`). Colunas: dropdown "Col N" ou "Col N — <cabeçalho>" (cabeçalho = linha `skipRows − 1`, se existir). Modo de valor: `SegmentedButton` "Valor único" / "Débito e crédito". Data: "dd/mm/aaaa", "mm/dd/aaaa", "aaaa-mm-dd". Decimal: "Vírgula" / "Ponto". "Data das parcelas": "Lançamento na fatura" / "Compra original". "Continuar" desabilitado enquanto `profile.mappingError != null` ou (`save` e nome vazio); o erro aparece em `colors.danger` acima dos botões. Keys: `map-delimiter`, `map-skip`, `map-date`, `map-desc`, `map-amount-mode`, `map-amount`, `map-debit`, `map-credit`, `map-category`, `map-origin`, `map-save`, `map-name`, `map-continue`.
aceite (texto do `extrato_conta.csv` inline no teste; app de teste com `bootstrap` em memória + conta "Conta Alfa"):
- Sem destino → "Continuar" desabilitado e texto 'Escolha a conta ou o cartão'.
- `skipRows` 2, categoria "Col 4 — Categoria", destino "Conta · Conta Alfa", "Continuar" → `profile` com `skipRows 2`, `categoryColumn 3`, `accountId` da conta, `save false`; a prévia mostrou 'PADARIA PAO BOM CURITIBA PR'.
- Marcar "Salvar como perfil" sem nome → desabilitado; com nome "Alfa CSV" → `save true`, `name 'Alfa CSV'`.
- Trocar separador para ',' recalcula a amostra sem exceção.
- `showImportTargetDialog(suggestCard: true)` com um cartão cadastrado → escolher o cartão → `format ofx`, `cardId` preenchido.
- `text: ''` abre sem exceção (sem amostra).

### T-086 · Tela de prévia da importação · `done` · deps: T-081, T-082 · parallel: yes
files: `lib/features/importing/presentation/import_preview_page.dart` (novo), `lib/features/importing/presentation/import_preview_row.dart` (novo), `test/features/importing/import_preview_page_test.dart` (novo)
contrato: SPEC §7.3 tabela Fase 8 (linha "Prévia") e parágrafo "Visual da prévia".
```dart
Future<ImportSession?> showImportPreview(BuildContext context, {required ImportSession session, required String sourceLabel,
  List<ImportLineError> errors = const [], Map<String, String> bankCategoryMap = const {},
  Future<TransactionRule?> Function(ImportRow row)? onCreateRule});
  // Navigator.push(MaterialPageRoute(fullscreenDialog: true)); pop(session) em "Importar N"; pop(null) em fechar/Cancelar
class ImportPreviewHeader extends StatelessWidget { const ImportPreviewHeader({super.key, required this.ultra}); final bool ultra; }
class ImportPreviewRow extends StatelessWidget {
  const ImportPreviewRow({super.key, required this.row, required this.ultra, required this.categoryOptions,
    required this.onInclude, required this.onCategory, this.onCreateInstallments, this.onCreateRule});
  final ImportRow row; final bool ultra;
  final List<TransactionCategory> categoryOptions; // já filtradas pelo kind da linha
  final ValueChanged<bool> onInclude; final ValueChanged<String?> onCategory;
  final ValueChanged<bool>? onCreateInstallments; final VoidCallback? onCreateRule;
}
String suggestionSourceLabel(SuggestionSource s); // 'Regra', 'Banco', 'Histórico', 'Dicionário'
```
Página: `Scaffold` sem `AppBar`; cabeçalho com título (`AppText.screenTitle`) `'Prévia da importação — $sourceLabel'` e `IconButton` fechar; linha de resumo `'$n linhas · $create a criar · $confirm a confirmar · $skipped ignoradas'` (+ `' · $futureInstallments parcelas futuras'` no Ultra) e, se `errors` não vazio, `'${errors.length} linhas com erro'` com `Tooltip` das 10 primeiras (`'Linha N: mensagem'`). Ultra: `FilterChip('Só sem categoria')` (índices de `uncategorizedIndices()`), botões "Marcar todas" / "Desmarcar todas". Tabela: `ListView.builder` com `itemExtent` 40 (Ultra) / 48 (Simples) sobre a lista de índices visíveis; Ultra com rolagem horizontal abaixo de 1100 px. Rodapé: "Cancelar" + `FilledButton('Importar ${create + confirm}')`, desabilitado quando 0. Depois que `onCreateRule` devolve regra não nula: `session = session.recategorize(AppScope.of(context).ledger.categorizer, bankCategoryMap: bankCategoryMap)`. Simples: sem origem/confiança, sem filtro, sem menu de regra, sem checkbox de parcelas (chip "3/10" só informativo); as flags viram um único `Icons.error_outline` (`warning`) com tooltip da 1ª flag. Categoria: `DropdownButton<String?>` denso (`isDense`, sem sublinhado) com 'Sem categoria' + `categoryOptions`.
aceite (sessão de 5 linhas montada no teste com o categorizador do Ledger e um matcher com uma transação existente que gera `probableDuplicate`):
- Linha com `probableDuplicate` começa desmarcada; botão mostra "Importar 4"; desmarcar outra → "Importar 3".
- Ultra mostra 'Dicionário' (ou 'Histórico') e confiança em linhas sugeridas; Simples não mostra esses textos nem 'Só sem categoria'.
- Ultra "Só sem categoria" deixa visíveis só as linhas sem categoria.
- Trocar a categoria no dropdown de uma linha é refletido na sessão devolvida (`categoryEdited true`).
- Menu "Criar regra a partir desta linha" chama `onCreateRule`; o teste grava a regra em `services.rules` e a devolve → a categoria das linhas não editadas que casam muda.
- "Importar N" devolve a sessão; fechar devolve `null`.
- Sessão de 2.000 linhas abre e rola (`drag`) sem exceção nos dois modos.

### T-087 · Regras: seção, formulário e reaplicar · `done` · deps: T-082 · parallel: yes
files: `lib/features/rules/presentation/rules_section.dart` (novo), `lib/features/rules/presentation/rule_form.dart` (novo), `test/features/rules/rules_section_test.dart` (novo)
contrato: SPEC §7.3 tabela Fase 8 (linhas "Regras" e "Form de regra"), §6.3 (reaplicar, reordenar).
```dart
class RulesSection extends StatelessWidget { const RulesSection({super.key}); } // ListenableBuilder(listenable: services.rules)
Future<TransactionRule?> showRuleForm(BuildContext context, {TransactionRule? initial, String? initialPattern,
  String? initialCategoryId, String? sampleDescription});
  // grava com services.rules.upsert e devolve a regra; nova regra: id newId(), priority = maior existente + 1 (ou 0)
Future<void> showReapplyRulesDialog(BuildContext context);
```
`SectionCard(title: 'Regras', trailing: Wrap[OutlinedButton 'Reaplicar às transações', FilledButton.icon 'Nova regra'])`. Lista: `ReorderableListView` (`shrinkWrap: true`, `physics: NeverScrollableScrollPhysics()`, `buildDefaultDragHandles: false`, `ReorderableDragStartListener` com `Icons.drag_indicator`); ao soltar → `rules.upsertAll(reorderRules(novaOrdem))`. Linha densa: handle, `Switch` ativa (upsert com `active` invertido), padrão, chip do tipo ('Contém'/'Começa com'/'Regex'), '→ <categoria>' (ou '—'), 'renomeia para "X"' se houver, editar, excluir (`confirmDialog`). Vazio: `EmptyState(icon: Icons.rule, message: 'Nenhuma regra. Crie regras para categorizar e renomear lançamentos automaticamente.', action: FilledButton 'Nova regra')`. Form (`showDialog`, máx. 520): padrão (validador `isValidRulePattern` → 'Padrão inválido'), `SegmentedButton` do tipo, categoria (despesas depois receitas, + 'Sem categoria'), 'Renomear para' (opcional), switch ativa; erro 'Defina categoria ou renomeação' se ambos vazios; botão "Testar padrão" → `matchingTransactions(rascunho, transactions.all)` → `'N transações casam'` + até 5 descrições; com `sampleDescription` mostra `'Casa com a linha'` / `'Não casa com a linha'`. Reaplicar: `AlertDialog` com `CheckboxListTile('Sobrescrever categorias já definidas')`; texto recalculado ao marcar: `'N transações vão mudar (X de categoria, Y de descrição)'` via `reapplyRules(compileRules(rules.all), transactions.all, categoriesById: ledger.categoriesById, overwriteCategory: ...)`; "Aplicar" (desabilitado se N = 0) → `transactions.upsertAll(mudanças)`.
aceite:
- Criar regra pelo form (padrão 'IFOOD', categoria Alimentação) faz a linha aparecer; padrão '(' com Regex mostra 'Padrão inválido' e não salva.
- `showRuleForm(initialPattern: 'LOJA EXEMPLO', sampleDescription: 'LOJA EXEMPLO PARC 03/10')` → "Testar padrão" mostra 'Casa com a linha'.
- Reordenar (arrastar a 2ª para o topo) → priorities 0..n-1 na nova ordem.
- Desligar o switch grava `active false`.
- Reaplicar com 2 transações sem categoria que casam → '2 transações vão mudar (2 de categoria, 0 de descrição)'; "Aplicar" categoriza; reabrir → '0 transações vão mudar …' com "Aplicar" desabilitado.

### T-088 · Dicionário: seção editável · `done` · deps: T-082 · parallel: yes
files: `lib/features/importing/presentation/dictionary_section.dart` (novo), `test/features/importing/dictionary_section_test.dart` (novo)
contrato: SPEC §7.3 tabela Fase 8 (linha "Dicionário").
```dart
class DictionarySection extends StatelessWidget { const DictionarySection({super.key}); }
Future<void> showDictionaryEntryForm(BuildContext context, {DictionaryEntry? initial});
```
`SectionCard(title: 'Dicionário de estabelecimentos', trailing: Wrap[TextButton 'Restaurar padrão', FilledButton.icon 'Novo padrão'])`; lista densa (`Column`, linhas de 32 px) ordenada por `categoryName` e depois `pattern`: padrão, '→ categoria', `StatusBadge(label: 'Categoria não encontrada', color: colors.warning)` quando `resolveCategoryByName` dá `null`, editar, excluir. Form: padrão (grava `foldText(texto.trim())`; vazio → 'Informe o padrão'), dropdown de categorias (grava o **nome**). "Restaurar padrão" com `confirmDialog` → `dictionary.replaceAll(defaultDictionary())`.
aceite:
- Com o dicionário padrão, a lista mostra 'UBER' e 'Transporte'.
- Novo padrão 'loja exemplo' → Compras grava `pattern 'LOJA EXEMPLO'`, `categoryName 'Compras'`.
- Entrada com `categoryName 'Inexistente'` mostra 'Categoria não encontrada'.
- Excluir uma entrada e depois "Restaurar padrão" volta a `kDefaultDictionary.length` entradas.

### T-089 · Fluxo de importação · `done` · deps: T-075, T-081, T-082, T-085, T-086, T-087 · parallel: no
files: `lib/features/importing/presentation/import_flow.dart` (novo), `test/features/importing/import_flow_test.dart` (novo)
contrato: SPEC §7.3 tabela Fase 8 (linha "Fluxo"), §6.3 "Importar".
```dart
typedef PickedImportFile = ({String name, List<int> bytes});
bool looksLikeOfx(String fileName, String text); // nome termina em .ofx (sem caixa) ou texto contém '<OFX' (sem caixa)
Future<void> startImport(BuildContext context, {ImportProfile? profile, Future<PickedImportFile?> Function()? pickFile});
```
Passos: (1) `pickFile ?? _pickWithFileSelector` (`openFile(acceptedTypeGroups: [XTypeGroup(label: 'Extratos', extensions: ['csv', 'ofx', 'txt'])])`, `readAsBytes`); `null` → retorna. (2) `text = decodeText(bytes)`; `isOfx = looksLikeOfx(name, text)`. (3) `profile` dado com formato diferente → SnackBar `'O arquivo não é CSV'` / `'O arquivo não é OFX'` e retorna. (4) OFX: `st = parseOfx(text)`; setup = perfil dado (`save: true`, para aprender de-para) ou `showImportTargetDialog(suggestCard: st.isCreditCard)`; linhas = `st.result.lines` (com `amountCents` negado se `invertSign`); erros = `st.result.errors`. CSV: setup = perfil dado (`save: true`) ou `showImportMappingDialog(text: text)`; `parseCsvLines(readCsv(text, delimiter: p.delimiter), p)`. Diálogo cancelado → retorna. (5) Sem linhas → SnackBar `'Nenhuma linha válida no arquivo.'`. (6) `ImportSession.build(lines:, target: ImportTarget(accountId: p.accountId, cardId: p.cardId), card: ledger.cardsById[p.cardId], categorizer: ledger.categorizer, matcher: ImportMatcher(transactions.all), bankCategoryMap: p.categoryMap)`. (7) `showImportPreview(sourceLabel: nome da conta/cartão, errors:, bankCategoryMap: p.categoryMap, onCreateRule: (row) => showRuleForm(context, initialPattern: normalizeDescription(row.line.description), initialCategoryId: row.categoryId, sampleDescription: row.line.description))`; `null` → retorna. (8) `plan = buildImportPlan(session, target:, card:, today: ledger.today, mode: p.installmentDateMode)`; `transactions.upsertAll([...plan.create, ...plan.update])`; se `save` → `importProfiles.upsert(p.learnBankCategories(learnedBankCategories(session)))`. (9) SnackBar `'${plan.create.length} lançamentos importados'` + `', ${plan.update.length} provisionados confirmados'` se > 0. `FormatException` em qualquer passo → SnackBar `'Não foi possível ler o arquivo: ${e.message}'`. Checar `context.mounted` após cada `await`.
aceite (fixtures de T-074/T-075 via `pickFile` injetado; app com `bootstrap` em memória, conta "Conta Alfa" e cartão de crédito "Cartão Beta" fecha 5/vence 12; clock 14/11/2026):
- `looksLikeOfx('x.OFX', '')` true; `('x.csv', '<ofx>')` true; `('x.csv', 'a;b')` false.
- Perfil CSV salvo (mapeamento do `extrato_conta.csv`, destino Conta Alfa) → prévia abre direto (sem assistente) → "Importar 4" → 11 transações criadas (3 simples + 8 do grupo 3/10), SnackBar '11 lançamentos importados'; o perfil gravado ganha `categoryMap` com as chaves `'ALIMENTACAO'`, `'SUPERMERCADO'` e `'COMPRAS'`.
- `fatura_cartao.ofx` sem perfil → diálogo de destino → "Cartão · Cartão Beta" → prévia com 'PAGAMENTO RECEBIDO' desmarcada → "Importar 2" → transação NETFLIX com `externalId 'CC-1'` e `cardId`, mais o grupo de 8 parcelas. Reimportar o mesmo arquivo → todas desmarcadas (`fitidDuplicate`/`existingInstallment`/`invoicePaymentLike`) e "Importar 0" desabilitado.
- Perfil CSV com arquivo `.ofx` → SnackBar 'O arquivo não é CSV'. Arquivo `x.ofx` com bytes de `'lixo'` → SnackBar começando com 'Não foi possível ler o arquivo'.

### T-090 · Página Importar · `done` · deps: T-087, T-088, T-089 · parallel: no
files: `lib/features/importing/presentation/import_page.dart` (novo), `test/features/importing/import_page_test.dart` (novo)
contrato: SPEC §7.3 tabela Fase 8 (linha "Página Importar").
```dart
class ImportPage extends StatelessWidget {
  const ImportPage({super.key, this.pickFile}); // pickFile só para teste; repassado a startImport
  final Future<PickedImportFile?> Function()? pickFile;
}
```
`ListenableBuilder(listenable: Listenable.merge([services.importProfiles, services.settings, services.ledger]))`; `ListView` com `PageHeader(title: 'Importar', actions: [FilledButton.icon(icon: Icon(Icons.upload_file), label: Text('Importar arquivo'))])`; `SectionCard(title: 'Perfis salvos')`: linha por perfil = (Ultra: `BankAvatar` do banco do destino), nome, destino ('Conta · X' / 'Cartão · X', ou 'Destino removido' em `warning`), chip 'CSV'/'OFX', `OutlinedButton('Importar')` → `startImport(context, profile: p, pickFile: pickFile)`, editar (CSV → `showImportMappingDialog(context, text: '', initial: p)`; OFX → `showImportTargetDialog(context, suggestCard: p.cardId != null, initial: p)`; resultado → `importProfiles.upsert(r.profile)`), excluir (`confirmDialog`). Vazio: `EmptyState(icon: Icons.upload_file, message: 'Nenhum perfil salvo. Importe um CSV ou OFX e salve o mapeamento para reaplicar com 1 clique.', action: botão 'Importar arquivo')`. Ultra: depois dos perfis, `RulesSection()` e `DictionarySection()`. `AppSpace.lg` entre seções.
aceite:
- Simples: 'Importar arquivo' e 'Perfis salvos' presentes; 'Regras' e 'Dicionário de estabelecimentos' ausentes.
- Ultra: as duas seções presentes.
- Sem perfis → `EmptyState`; com 1 perfil → nome e chip visíveis; excluir com confirmação remove.
- Botão 'Importar' do perfil com `pickFile` que devolve `null` não lança.

### T-091 · Shell e Transações: entrada "Importar" · `done` · deps: T-089, T-090 · parallel: no
files: `lib/app/home_shell.dart`, `lib/features/transactions/presentation/transactions_page.dart`, `test/app/smoke_test.dart`, `test/features/transactions/transactions_page_test.dart`
contrato: SPEC §7.3 (páginas, índice 5 Importar). `_navItems` ganha `(label: 'Importar', icon: Icons.upload_file)` na posição 5; `_pageFor`: 5 → `ImportPage()`, 6 Recorrentes, 7 Categorias, 8 Ajustes; `_badges` mantém os índices 2 e 4. `TransactionsPage`: `OutlinedButton.icon(icon: Icon(Icons.upload_file), label: Text('Importar'), onPressed: () => startImport(context))` nas `actions` do `PageHeader`, nos dois modos, antes dos botões existentes.
aceite:
- Smoke test: `_pages` com 'Importar' entre 'Transações' e 'Recorrentes'; navega as 9 páginas nos dois modos em 1400×900 e na sidebar colapsada 800×700 sem exceção.
- Transações mostra o botão 'Importar' em Simples e Ultra.
- Testes existentes passam.

### T-092 · Documentação da Fase 8 · `done` · deps: T-070..T-091 · parallel: no
files: `CONTEXT.md`, `ROADMAP.md`, `docs/BACKLOG.md`
contrato: CONTEXT §4 (árvore com `features/rules/` e `features/importing/`, `text_normalize.dart`), §5 (página Importar, prévia, regras, dicionário, sugestão no form), §7 (boxes `fm_rules`, `fm_import_profiles`, `fm_dictionary`; backup cobre as 3), §8 (testes novos, fixtures, total), §10 (commit), §11 (status), §12 (limites: dicionário vazio volta ao padrão no boot; "N/M" no fim da descrição pode ser falso positivo de parcela; pagamento de fatura no extrato só é sinalizado, não convertido em `invoicePayment`). ROADMAP: Fase 8 em "v3". BACKLOG: T-070..T-091 `done`.
aceite: total de testes igual ao de `flutter test`; `bash tool/check.sh` → `CHECK OK`.

## Fase 9 — Produtividade

> Origem: `docs/V3_DIRECTION.md` (Produtividade). Contratos: SPEC §3.8, §5.17–5.19, §6.3 (ações em massa e inline), §7.3 "Produtividade (Fase 9)".
> Sem dependência nova: `Shortcuts`/`Actions`/`CallbackShortcuts`/`Focus`. Lógica pura primeiro (fuzzy, busca, operações em massa, padrão de regra, seleção), com testes; UI depois.
> Decisões fechadas: valor de parcela **não** é editável inline; inline de valor desligado com `hideValues`; `/` foca a busca de Transações só no Ultra com a página aberta, senão abre a paleta; Simples tem paleta e atalhos, sem seleção nem inline; barra de ações em massa extensível (Tags entram na Fase 10).
> Ondas (tarefas da mesma onda têm arquivos disjuntos): **A** T-100, T-101, T-102, T-103, T-104 · **B** T-105, T-106, T-107, T-108 · **C** T-109, T-110 · **D** T-111 · **E** T-112 · **F** T-113 · **G** T-114 · **H** T-115.
> Datas nos testes: `DateTime(2026, 11, 14)` como "hoje". App de teste igual a `test/features/transactions/transactions_page_test.dart` (`bootstrap` em memória, `seedDemo`, `clock`).
> Teclado nos testes: `tester.sendKeyEvent(LogicalKeyboardKey.keyN)`; Ctrl = `sendKeyDownEvent(LogicalKeyboardKey.controlLeft)` … `sendKeyUpEvent`; `/` com `sendKeyEvent(LogicalKeyboardKey.slash, character: '/')`.

### T-100 · Busca aproximada (core) · `done` · deps: — · parallel: yes
files: `lib/core/utils/fuzzy.dart` (novo), `test/core/fuzzy_test.dart` (novo)
contrato: SPEC §3.8 inteiro (`foldedWords`, `fuzzyTokenScore`, `fuzzyScore`, `fuzzyRank`). Dart puro; importa só `text_normalize.dart`. Regex em `final` de topo.
aceite:
- Os 9 exemplos de `fuzzyScore` do SPEC §3.8.
- `foldedWords('UBER *TRIP 8X') == ['UBER', 'TRIP', '8X']`; `foldedWords('') == []`.
- `fuzzyTokenScore('TRIP', 'UBER *TRIP', ['UBER', 'TRIP']) == 3`.
- `fuzzyRank(['Nova recorrência', 'Nova transação', 'Ajustes'], 'nova', (s) => [s])` == `['Nova recorrência', 'Nova transação']` (empate mantém a ordem); com `'trans'` → `['Nova transação']`; com `''` e `limit: 2` → os 2 primeiros na ordem de entrada.
- `fuzzyRank` usa o maior score entre os textos: item com textos `['Importar arquivo', 'csv']` e query `'csv'` aparece.

### T-101 · Operações em massa e edição inline (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/transactions/domain/transaction_bulk.dart` (novo), `test/features/transactions/transaction_bulk_test.dart` (novo)
contrato: SPEC §5.18 inteiro (`BulkResult`, `bulkRecategorize`, `bulkConfirmPlanned`, `installmentGroupsOf`, `bulkDeleteIds`, `commonCategoryId`, `canEditCategoryInline`, `canEditAmountInline`, `parseInlineAmount`). Dart puro; usa `copyWith` (limpa `categoryId` com `null`), `dateOnly`, `parseMoney`, `CategoryKind`.
aceite: todos os exemplos do SPEC §5.18, mais:
- `bulkRecategorize` com pagamento de fatura e transferência → ambos em `skipped`; `changed` preserva a ordem de entrada.
- `bulkConfirmPlanned` não toca transação `paid` (fica em `skipped`) e a `date` resultante é `dateOnly`.
- `commonCategoryId([])`, `commonCategoryId([a])` (sem categoria) e `commonCategoryId([b, c])` (categorias diferentes) → `null`; duas com `cat_mercado` → `'cat_mercado'`.
- `canEditCategoryInline` true para despesa e receita, false para transferência e pagamento de fatura; `canEditAmountInline` true para transferência não parcelada.

### T-102 · Padrão de regra a partir da seleção · `done` · deps: — · parallel: yes
files: `lib/features/rules/domain/rule_suggestion.dart` (novo), `test/features/rules/rule_suggestion_test.dart` (novo)
contrato: SPEC §5.19 inteiro (`suggestRulePattern`). Dart puro; usa `foldText`.
aceite:
- Os 9 exemplos do SPEC §5.19.
- Invariante: para cada exemplo com resultado não vazio, `CompiledRule(TransactionRule(id: 'r', pattern: resultado)).matches(s)` é true para todos os assuntos.

### T-103 · Seleção de transações (lógica) · `done` · deps: — · parallel: yes
files: `lib/features/transactions/presentation/transaction_selection.dart` (novo, Dart puro: sem `package:flutter`), `test/features/transactions/transaction_selection_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", bloco `TransactionSelection`. Imutável; cada operação devolve nova instância.
aceite (order = `['a', 'b', 'c', 'd', 'e']`):
- `empty.toggle('b')` → ids `{b}`, anchor `b`; `.toggle('b')` de novo → ids `{}`, anchor `b`.
- `empty.toggle('b').extendTo('d', order)` → `{b, c, d}`, anchor `b`; depois `.extendTo('a', order)` → `{a, b, c, d}`.
- `empty.extendTo('c', order)` (sem âncora) → `{c}`, anchor `c`; âncora `'z'` fora de order → igual a `toggle`.
- `selectAll(order)` → 5 ids, anchor mantido; `selectedIn(['e', 'a', 'x'])` sobre `{a, e}` → `['e', 'a']`.
- `allState`: `[]` → false; nenhum → false; `{a, b}` → null; todos → true; ids extras fora de order não impedem `true`.

### T-104 · Atalhos: intents, mapas e guarda de digitação · `done` · deps: — · parallel: yes
files: `lib/app/app_shortcuts.dart` (novo), `test/app/app_shortcuts_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", bloco **Atalhos** (`OpenPaletteIntent`, `NewTransactionIntent`, `FocusSearchIntent`, `ImportFileIntent`, `GoToPageIntent`, `SelectAllRowsIntent`, `ClearSelectionIntent`, `kAppShortcuts`, `kSelectionShortcuts`, `isTextInputFocused`, `TypingGuardAction`). Mapas `final` (não `const`).
aceite (widget de teste: `Shortcuts(kAppShortcuts)` > `Actions` com `TypingGuardAction` para N, `/` e dígitos e `CallbackAction` para Ctrl+K/Ctrl+I, gravando os intents recebidos numa lista > `Focus(autofocus: true)` com um `TextField` key `campo`):
- Sem foco no campo: N → `NewTransactionIntent`; `3` → `GoToPageIntent(2)`; `numpad9` → `GoToPageIntent(8)`; `/` → `FocusSearchIntent`; Ctrl+K → `OpenPaletteIntent`; Ctrl+I → `ImportFileIntent`.
- Com foco no `TextField` (tap): `isTextInputFocused() == true`; N, `3` e `/` não geram intent; Ctrl+K gera `OpenPaletteIntent`.
- Shift+N não gera `NewTransactionIntent` (SingleActivator exige modificadores exatos).
- `kSelectionShortcuts`: Ctrl+A → `SelectAllRowsIntent`, Esc → `ClearSelectionIntent`; com foco no campo, a `TypingGuardAction` de Ctrl+A fica desabilitada (nenhum intent gravado).

### T-105 · Busca de transações (domínio) · `done` · deps: T-100 · parallel: yes
files: `lib/features/transactions/domain/transaction_search.dart` (novo), `test/features/transactions/transaction_search_test.dart` (novo)
contrato: SPEC §5.17 inteiro (`TransactionSearchIndex`, regras 1–4). Pré-dobra no construtor; `search` não chama `foldText` por transação.
aceite: todos os exemplos e o teste de desempenho do SPEC §5.17, mais: empate de score e data → `id` asc; `search('uber', limit: 1)` → `[t2]`; query `'  UBER  '` igual a `'uber'`.

### T-106 · Paleta de comandos (widget) · `done` · deps: T-100 · parallel: yes
files: `lib/app/command_palette.dart` (novo), `test/app/command_palette_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", bloco **Paleta** (`PaletteEntry`, `showCommandPalette`, visual, teclado, keys `palette-input`/`palette-item-$i`). Cores por `context.colors`; texto do rodapé exato.
aceite (comandos de teste: 'Nova transação' (shortcut 'N'), 'Nova recorrência', 'Ir para Painel' ('1'); `onRun` grava numa lista):
- Abre com foco no campo; mostra os 3 comandos, cabeçalho 'Comandos' e o rodapé '↑↓ navegar · Enter executar · Esc fechar'; chip 'N' visível.
- Digitar 'nova' → 2 itens; ↓ e Enter → executa 'Nova recorrência' e a paleta fecha.
- `onRun` roda depois do pop: no `onRun` de teste, `find.byType(Dialog)` já não encontra nada (gravar o resultado e checar).
- ↑ no primeiro item mantém o destaque no primeiro; ↓ além do último mantém no último.
- `search` devolvendo 2 entradas `group: 'Transações'` para query 'ab' → cabeçalho 'Transações' aparece depois dos comandos; clique na 2ª executa ela.
- 'xyz' sem resultados → 'Nada encontrado'; Enter não faz nada.
- Esc fecha sem executar.

### T-107 · Células inline: categoria e valor · `done` · deps: T-101 · parallel: yes
files: `lib/features/transactions/presentation/inline_cells.dart` (novo), `test/features/transactions/inline_cells_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", bloco **Edição inline** (`InlineCategoryCell`, `InlineAmountCell`). Valor via `parseInlineAmount`; texto inicial = `formatMoney(amountCents)` sem o prefixo `R$ ` (mesmo `replaceFirst` de `transaction_form.dart`).
aceite:
- `InlineCategoryCell` com 2 opções: escolher a 2ª chama `onChanged` com o id; escolher 'Sem categoria' chama com `null`.
- `InlineAmountCell(amountCents: 1250)`: clique → campo com '12,50'; digitar '20,00' + Enter → `onSubmit(2000)` e volta a exibir `display`.
- '0' + Enter ou 'abc' + Enter → não chama `onSubmit` e o campo continua visível.
- '12,50' + Enter (igual) → não chama `onSubmit` e sai da edição.
- Esc → sai sem chamar; tirar o foco (tap fora) → sai sem chamar.
- Célula dentro de um `InkWell(onTap: …)`: clicar no valor não dispara o `onTap` do `InkWell`.

### T-108 · Barra de ações em massa e diálogos · `done` · deps: T-101 · parallel: yes
files: `lib/features/transactions/presentation/bulk_action_bar.dart` (novo), `lib/features/transactions/presentation/bulk_dialogs.dart` (novo), `test/features/transactions/bulk_dialogs_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", blocos **Barra de ações em massa** e **Diálogos** (`BulkAction`, `BulkActionBar`, `CategoryChoice`, `showBulkCategoryDialog`, `showBulkConfirmDialog`, `BulkDeleteScope`, `showBulkDeleteDialog`). `DropdownButtonFormField` com `initialValue`; guarda contra duplo pop (flag `answered`, como `transactions_page.dart`).
aceite:
- `BulkActionBar(count: 3, …)` mostra '3 selecionadas', os rótulos das ações e o tooltip 'Limpar seleção (Esc)'; ação com `onPressed: null` fica desabilitada; ação `destructive` usa `colors.danger`; `onClear` é chamado no X.
- `showBulkCategoryDialog` (categorias de `defaultCategories()`): escolher 'Mercado' e confirmar → `(category: <Mercado>)`; 'Sem categoria' → `(category: null)`; Cancelar → `null`; receitas aparecem com ' (receita)'.
- `showBulkConfirmDialog(count: 2, initialDate: 14/11/2026)` → título 'Confirmar 2 provisionados'; Confirmar sem mudar a data → `DateTime(2026, 11, 14)`; Cancelar → `null`.
- `showBulkDeleteDialog(count: 3, groups: 0, …)` → 'Excluir 3 transações?' e 'Excluir' → `BulkDeleteScope.selected`; `(count: 2, groups: 1, wholeGroupsCount: 4)` → botões 'Só as 2 selecionadas' e 'Grupos inteiros (4 lançamentos)' devolvem `selected` / `wholeGroups`.

### T-109 · Comandos da paleta e entradas de transação · `done` · deps: T-105, T-106 · parallel: yes (com T-110)
files: `lib/app/app_commands.dart` (novo), `test/app/app_commands_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", bloco **Comandos**.
```dart
typedef PageInfo = ({String label, IconData icon});
List<PaletteEntry> buildAppCommands({required AppSettings settings, required List<PageInfo> pages,
  required ValueChanged<int> onGoTo, required VoidCallback onNewTransaction, required VoidCallback onImport,
  required VoidCallback onNewRecurring, required VoidCallback onToggleMode, required VoidCallback onToggleTheme,
  required VoidCallback onToggleHideValues});
List<PaletteEntry> transactionEntries(List<Transaction> found, {required Ledger ledger, required ValueChanged<Transaction> onOpen});
PaletteEntry filterTransactionsEntry(String query, {required VoidCallback onRun});
```
aceite:
- Com 9 páginas: 15 comandos na ordem do SPEC; 'Ir para Transações' tem `shortcut '5'` e `onRun` chama `onGoTo(4)`; 'Nova transação' `shortcut 'N'`; 'Importar arquivo' `shortcut 'Ctrl+I'`.
- `settings.mode == simple` → 'Mudar para Modo Ultra'; `ultra` → 'Mudar para Modo Simples'; `hideValues: true` → 'Mostrar valores'.
- `fuzzyRank(cmds, 'csv', (e) => [e.label, ...e.keywords])` encontra 'Importar arquivo'; `'escuro'` encontra 'Alternar tema claro/escuro'.
- `transactionEntries` com parcela 3/10 de 'Loja Exemplo' em cartão 'Cartão Beta' com categoria 'Compras', data 14/11/2026 → label 'Loja Exemplo 3/10', subtitle '14/11/2026 · Cartão Beta · Compras', `group 'Transações'`; `onRun` chama `onOpen` com a transação.
- `filterTransactionsEntry('uber', …)` → label 'Filtrar Transações do mês por “uber”', `group 'Transações'`.

### T-110 · Linha e cabeçalho: checkbox e células inline · `done` · deps: T-107 · parallel: yes (com T-109)
files: `lib/features/transactions/presentation/transaction_row.dart`, `test/features/transactions/transaction_row_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", parágrafos **Transações Ultra com seleção** (coluna, cor de fundo, `kTxSelectWidth = 36`, `kTxUltraMinWidth = 796`) e `TransactionRow` (parâmetros novos e keys). `TransactionColumns` ganha `Widget? leading` (não nulo → `SizedBox(width: kTxSelectWidth)` antes da data). `TransactionTableHeader` ganha `bool selectable = false`, `bool? selectAllState`, `VoidCallback? onSelectAll` (checkbox tristate key `tx-select-all`). Todos os parâmetros novos são opcionais: sem eles a linha é idêntica à atual.
aceite:
- Sem os parâmetros novos: nenhum `Checkbox`, nenhum `InlineCategoryCell`/`InlineAmountCell` (testes existentes de Transações passam sem mudança).
- `selected: true` → checkbox marcado key `tx-select-<id>` e fundo `primarySubtle` mesmo em provisionado; tocar no checkbox chama `onToggleSelect` e não chama `onAction(edit)`.
- Despesa com `categoryOptions` + `onCategoryChanged` → `InlineCategoryCell` key `inline-category-<id>`; transferência com os mesmos parâmetros → texto '—' (sem dropdown).
- `onAmountChanged` não nulo → `InlineAmountCell` key `inline-amount-<id>`; nulo → `MoneyText`.
- Cabeçalho com `selectable: true, selectAllState: null` → checkbox tristate; tocar chama `onSelectAll`.
- Linha Ultra com checkbox dentro de `SizedBox(width: kTxUltraMinWidth)`: sem overflow.

### T-111 · Transações: multi-seleção e ações em massa · `done` · deps: T-101, T-102, T-103, T-104, T-108, T-110 · parallel: no
files: `lib/features/transactions/presentation/transactions_page.dart`, `test/features/transactions/transactions_bulk_test.dart` (novo), `test/features/transactions/transactions_page_test.dart` (só se algum teste existente precisar de ajuste pela coluna nova)
contrato: SPEC §6.3 "Ações em massa", §7.3 "Produtividade (Fase 9)" (**Transações Ultra com seleção**, **Barra de ações em massa**, **Diálogos**, SnackBars). `TransactionsPage({super.key, this.focusNode})` (`FocusNode?`; nulo → nó próprio criado e descartado pela página). Estado `TransactionSelection _selection`; `visible = _selection.selectedIn(ids das linhas)`; `HardwareKeyboard.instance.isShiftPressed` decide `toggle`/`extendTo`. Página envolta em `Shortcuts(shortcuts: kSelectionShortcuts)` > `Actions({SelectAllRowsIntent: TypingGuardAction(...), ClearSelectionIntent: TypingGuardAction(...)})` > `Focus(focusNode: ..., autofocus: true)`; no Simples as ações não fazem nada. Mudar o mês zera a seleção. Ações: recategorizar (categorias de `s.categories.all`), confirmar (data inicial `ledger.today`), criar regra (`showRuleForm` + `reapplyRules` com a regra devolvida), excluir (`groups = installmentGroupsOf(sel).length`; `wholeGroupsCount = bulkDeleteIds(sel, all, wholeGroups: true).length`). Uma gravação por ação.
aceite (seed demo, Ultra, 1400×900, mês 11/2026):
- Ultra mostra checkboxes; Simples não (nem barra).
- Marcar 2 checkboxes → '2 selecionadas'; Shift+clique no 5º com âncora no 1º → '5 selecionadas'; Esc → barra some.
- Ctrl+A (página focada, sem campo focado) → 'N selecionadas' com N = linhas visíveis; com foco no campo de busca, Ctrl+A não seleciona linhas.
- Filtrar pela busca depois de selecionar tudo → a contagem cai para as linhas visíveis.
- Recategorizar 2 despesas para 'Lazer' → ambas com `cat_lazer` no repositório e SnackBar '2 recategorizadas'; com 1 receita junto → '2 recategorizadas · 1 ignoradas (tipo incompatível)'.
- Selecionar 2 provisionados (`status planned`, criados no teste se o seed não tiver) → 'Confirmar pagamento' habilitado → Confirmar → os 2 `paid` com data 14/11/2026; seleção sem provisionado → botão desabilitado.
- Excluir 2 transações simples → confirmação → removidas, SnackBar '2 transações excluídas', barra some.
- Seleção com 1 parcela de um grupo de 3 (criado no teste com `buildInstallments`, datas em 11/2026 para a 1ª) + 1 simples: 'Só as 2 selecionadas' remove 2; repetir com 'Grupos inteiros (4 lançamentos)' remove o grupo inteiro e a simples.
- 'Criar regra' com 2 transações 'UBER *TRIP 1' e 'UBER *TRIP 2' (criadas no teste) → form abre com padrão 'UBER *TRIP'; escolher 'Transporte' e salvar → regra gravada e as 2 com `cat_transporte`; SnackBar 'Regra criada · 2 transações atualizadas'.

### T-112 · Transações: edição inline, busca focável e dicas · `done` · deps: T-111 · parallel: no
files: `lib/features/transactions/presentation/transactions_page.dart`, `lib/features/transactions/presentation/transaction_filters.dart`, `test/features/transactions/transactions_inline_test.dart` (novo)
contrato: SPEC §6.3 "Edição inline", §7.3 "Produtividade (Fase 9)" (**Edição inline**, `/`, **Dicas de atalho**). `TransactionsPage` ganha `this.searchFocusNode` (`FocusNode?`) e `this.initialQuery` (`String?`; estado inicial `_filter = TransactionFilter(query: initialQuery ?? '')`). `TransactionFilterBar` ganha `FocusNode? searchFocusNode` repassado ao `TextField` de busca. Ultra passa a cada linha: `categoryOptions` (listas por `CategoryKind`, por nome, montadas uma vez por build) + `onCategoryChanged` → `upsert(t.copyWith(categoryId: v))`; `onAmountChanged` só se `canEditAmountInline(t) && !settings.hideValues` → `upsert(t.copyWith(amountCents: v))`. Simples não passa nada. Botão 'Nova transação' em `Tooltip(message: 'Atalho: N')`; botão 'Importar' em `Tooltip(message: 'Atalho: Ctrl+I')`.
aceite (seed demo, Ultra, 1400×900):
- Trocar a categoria de uma despesa pelo dropdown da célula → repositório atualizado; o formulário não abre.
- Clicar no valor de uma despesa não parcelada, digitar '99,90' + Enter → `amountCents 9990`; Esc → sem mudança.
- Parcela não tem `InlineAmountCell`; com `hideValues: true` nenhuma linha tem `InlineAmountCell`.
- Simples: nenhum `InlineCategoryCell` nem `InlineAmountCell`.
- `initialQuery: 'Mercado'` → campo de busca com 'Mercado' e só linhas que casam.
- `searchFocusNode.requestFocus()` → o `TextField` de busca fica focado.
- Tooltips 'Atalho: N' e 'Atalho: Ctrl+I' presentes nos dois modos.

### T-113 · Shell: atalhos globais, foco e paleta · `done` · deps: T-104, T-109, T-112 · parallel: no
files: `lib/app/home_shell.dart`, `test/app/shell_shortcuts_test.dart` (novo)
contrato: SPEC §7.3 "Produtividade (Fase 9)", parágrafos **Foco do shell**, **Paleta** e **Comandos**. `Shortcuts(shortcuts: kAppShortcuts)` > `Actions` (N, `/` e `GoToPageIntent` com `TypingGuardAction`; Ctrl+K e Ctrl+I com `CallbackAction`) > `Focus(focusNode: _shellFocus, autofocus: true)` > `Scaffold`. `FocusNode`s `_shellFocus`, `_txFocus`, `_txSearchFocus` criados no `initState` e descartados no `dispose`; `FocusManager.instance.addListener(_reclaimFocus)` (removido no `dispose`). `_pageFor(4)` → `TransactionsPage(key: ValueKey('tx-$_txEpoch'), focusNode: _txFocus, searchFocusNode: _txSearchFocus, initialQuery: _txQuery)`. `_openPalette()`: se `_paletteOpen` retorna; índice = `TransactionSearchIndex(ultra ? all : all.where((t) => !isProvisioned(t)))`; `showCommandPalette(commands: buildAppCommands(...), search: (q) => q.trim().length < 2 ? [] : [if (ultra) filterTransactionsEntry(q, onRun: () => setState(() { _txQuery = q; _txEpoch++; _index = 4; })), ...transactionEntries(index.search(q), ledger: ..., onOpen: (t) => showTransactionForm(context, initial: t))])`. Comandos: `onNewRecurring` → `showRecurringForm(context)`; `onToggleMode`/`onToggleTheme`/`onToggleHideValues` → `services.settings.update(...)`; tema: `Theme.of(context).brightness == Brightness.dark ? ThemePreference.light : ThemePreference.dark`. `_navItems` passa como `pages`.
aceite (app completo como no smoke test, 1400×900, seed demo):
- N → diálogo 'Nova transação' abre; Esc fecha; N com o diálogo aberto não abre outro.
- `5` → página Transações; `9` → Ajustes; `numpad1` → Painel.
- Ctrl+K → paleta; digitar 'ajus' + Enter → página Ajustes.
- Paleta: digitar a descrição de uma transação do seed → item no grupo 'Transações'; Enter até o item (↓) → formulário 'Editar transação'.
- Ultra: Ctrl+K, digitar 'mercado', escolher 'Filtrar Transações do mês por “mercado”' → página Transações com 'mercado' no campo de busca.
- Ultra na página Transações: `/` foca o campo de busca (`isTextInputFocused() == true`) e N em seguida não abre o formulário. Simples na página Transações: `/` abre a paleta.
- Comandos 'Mudar para Modo Ultra', 'Ocultar valores' e 'Alternar tema claro/escuro' mudam `settings.mode`, `hideValues` e `theme`.
- Depois de excluir uma transação pelo menu da linha (o nó focado some), `1` continua navegando (reclaim de foco).

### T-114 · Shell: dicas de atalho e entrada "Buscar" · `done` · deps: T-113 · parallel: no
files: `lib/app/home_shell.dart`, `test/app/smoke_test.dart`
contrato: SPEC §7.3 "Produtividade (Fase 9)", parágrafo **Dicas de atalho** (FAB `tooltip: 'Atalho: N'`; sidebar larga: `Tooltip('Atalho: {i+1}')` por item e entrada 'Buscar' com 'Ctrl+K', key `sidebar-search`; colapsada: tooltip '{rótulo} · {i+1}' e `IconButton(Icons.search, tooltip: 'Buscar (Ctrl+K)')`; as duas chamam `_openPalette`).
aceite:
- Smoke test atualizado: na sidebar colapsada navega com `find.byTooltip('$label · ${i + 1}')`; as 9 páginas nos dois modos em 1400×900 e 800×700 sem exceção.
- Sidebar larga: `find.byKey(const ValueKey('sidebar-search'))` presente; tap → paleta abre (hint 'Buscar comandos e transações').
- Sidebar colapsada: tooltip 'Buscar (Ctrl+K)' presente; tap → paleta abre.
- FAB com tooltip 'Atalho: N'.

### T-115 · Documentação da Fase 9 · `done` · deps: T-100..T-114 · parallel: no
files: `CONTEXT.md`, `ROADMAP.md`, `docs/BACKLOG.md`
contrato: CONTEXT §4 (árvore com `app_shortcuts.dart`, `command_palette.dart`, `app_commands.dart`, `core/utils/fuzzy.dart`, `transaction_search.dart`, `transaction_bulk.dart`, `rule_suggestion.dart`, `transaction_selection.dart`, `inline_cells.dart`, `bulk_action_bar.dart`, `bulk_dialogs.dart`), §5 (tabela de atalhos, paleta, multi-seleção, ações em massa, edição inline; diferenças Simples/Ultra), §8 (testes novos, total), §10 (commit), §11 (status), §12 (limites: valor de parcela não editável inline; `/` só foca a busca de Transações no Ultra; atalhos não valem dentro de diálogos; busca da paleta é por descrição e valor exato, sem notas; "Filtrar Transações" vale só para o mês exibido; Shift+clique só no checkbox). ROADMAP: Fase 9 em "v3". BACKLOG: T-100..T-114 `done`.
aceite: total de testes igual ao de `flutter test`; `bash tool/check.sh` → `CHECK OK`.

## Fase 10 — Subcategorias, tags, metas e "posso gastar hoje"

> Origem: `docs/V3_DIRECTION.md` (Domínios novos). Contratos: SPEC §3.5 (Fase 10), §4.3, §4.4, §4.6, §4.9, §5.6, §5.13, §5.14, §5.16, §5.17, §5.20–5.23, §6.1–6.3 (Fase 10), §7.3 "Subcategorias, tags, metas e posso gastar hoje (Fase 10)".
> Sem dependência nova. Domínio puro primeiro, com os exemplos do SPEC como teste; Ledger/persistência; UI por último.
> Decisões fechadas: subcategoria de 1 nível; vínculo inválido vira raiz (nunca derruba). Orçamento do pai cobre pai + filhas; filha tem orçamento próprio opcional. `resolveCategoryByName` aceita caminho 'Pai › Filha' e nome simples (raiz vence; filhas homônimas = ambíguo). Tags normalizadas (trim, sem '#', sem duplicata por `foldText`); regras só **acrescentam** tags. Metas são seção da página Contas (sem página nova: atalhos 1–9 intactos); aporte nunca passa do saldo atual livre da conta; meta arquivada libera a reserva. "Posso gastar hoje" reusa os eventos da previsão: contas ativas (todos os tipos), faturas em aberto com vencimento ≤ próxima receita (inclusive; vencidas entram), despesas provisionadas e recorrências de despesa de conta até lá; próxima receita = próxima ocorrência **depois de hoje** de recorrência de receita ativa em conta ativa; sem ela, fim do mês; reserva efetiva limitada ao saldo positivo da conta; livre ≤ 0 → "Sem folga", 0/dia. Simples: card do Painel, árvore de categorias e metas enxutas; tags só no Ultra (Simples preserva as tags existentes).
> Dependência da Fase 9: T-139, T-140 e T-141 tocam `transactions_page.dart`, `transaction_filters.dart`, `transaction_row.dart`, `transaction_search.dart`, `app_commands.dart`, `inline_cells.dart` e `bulk_dialogs.dart` → só começam com a Fase 9 fechada (T-115 `done`). `bulk_action_bar.dart` e `home_shell.dart` **não** são tocados (a ação 'Tags' é só mais um `BulkAction` montado pela página).
> Ondas (tarefas da mesma onda têm arquivos disjuntos): **A** T-120, T-121, T-122, T-123 · **B** T-124, T-125, T-126, T-127 · **C** T-128, T-129, T-130, T-131, T-132, T-133, T-135, T-136, T-138 · **D** T-134, T-137 · **E** (Fase 9 fechada) T-139, T-140 · **F** T-141 · **G** T-142.
> Datas nos testes: `DateTime(2026, 11, 15)` como "hoje" (salvo indicação). App de teste igual a `test/features/transactions/transactions_page_test.dart` (`bootstrap` em memória, `seedDemo` quando útil, `clock`).

### T-120 · Subcategorias: `parentId`, `CategoryTree` e orçamento agregado (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/categories/domain/transaction_category.dart`, `lib/features/categories/domain/category_tree.dart` (novo), `lib/features/categories/domain/category_spending.dart`, `test/features/categories/category_tree_test.dart` (novo)
contrato: SPEC §4.3 (bloco "Subcategorias (Fase 10)": `parentId` com `_keep`, `toMap` só não nulo, `fromMap` tolerante, `==`/`hashCode`), §5.20 inteiro (`kCategoryPathSeparator`, `CategoryTree`, `categoryParentError`), §5.6 "Orçamento com subcategorias" (`budgetStatuses(..., {CategoryTree? tree})`). Dart puro; ordenação por `foldText(name)` (`core/utils/text_normalize.dart`). `CategoryTree` pré-indexa no construtor (mapas id → categoria e pai → filhas); consultas O(1).
aceite:
- Entidade: round-trip com e sem `parentId`; `fromMap` sem a chave → `null`; `copyWith(parentId: null)` limpa; omitido mantém; `toMap()` sem `parentId` não tem a chave.
- Todos os exemplos de §5.20 (labels, `options(expense)` na ordem dada, `rollUp`, `categoryParentError` ×5).
- `childrenOf('tra') == const []`; `hasChildren('ali')` true; `rootOf('mer') == 'ali'`; `rootOf('nada') == 'nada'`; `CategoryTree.empty.label('x') == ''`.
- Exemplo de orçamento de §5.6 (Alimentação spent 90000, ratio 0.9; Mercado spent 50000); sem `tree` o resultado é o atual (Alimentação spent 10000).
- Testes existentes passam (`budgetStatuses` sem o parâmetro novo).

### T-121 · Tags: `Transaction.tags` e funções de tag (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/transactions/domain/transaction.dart`, `lib/features/transactions/domain/tags.dart` (novo), `lib/features/transactions/domain/installments.dart`, `test/features/transactions/tags_test.dart` (novo)
contrato: SPEC §4.4 bloco "Fase 10 (`tags`)" e §5.21 inteiro (`normalizeTag`, `tagKey`, `normalizeTags`, `parseTagInput`, `hasAnyTag`, `bulkAddTags`, `bulkRemoveTags`, `tagUsage`). `tags.dart` importa `transaction.dart` e vice-versa (import circular é válido em Dart). Construtor: `tags = raw.isEmpty ? const [] : List.unmodifiable(normalizeTags(raw))`. `buildInstallments` passa `tags: base.tags`.
aceite:
- Todos os exemplos de §5.21.
- `Transaction(..., tags: [' #Viagem', 'viagem', 'casa']).tags == ['Viagem', 'casa']`; a lista é imutável (`add` lança).
- `fromMap` sem `'tags'`, com `null`, com `'x'` (não lista) e com `['a', 1, null]` → `[]`, `[]`, `[]`, `['a']`; `toMap()` sem tags não tem a chave; round-trip com tags.
- `==`: mesmas tags em outra ordem → diferente; mesmas tags → igual e mesmo `hashCode`; `copyWith()` mantém tags; `copyWith(tags: [])` limpa.
- `buildInstallments` com base de tags `['x']` em 3 parcelas → as 3 com `['x']`.
- Testes existentes de transações passam.

### T-122 · Metas: entidade `Goal` e regras de reserva (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/goals/domain/goal.dart` (novo), `lib/features/goals/domain/goal_math.dart` (novo), `test/features/goals/goal_test.dart` (novo)
contrato: SPEC §4.9 inteiro (`GoalMovement`, `Goal`) e §5.22 inteiro (`reservedByAccount`, `availableToReserve`, `contributionError`, `withdrawalError`, `removeMovementError`, `overReservedCents`, `monthlyContributionNeeded`, `isGoalOverdue`, regras 1–4). Dart puro; mensagens com `formatMoney`; datas com `dateOnly`/`dateKey`/`parseDateKey`.
aceite:
- Todos os exemplos de §5.22.
- `Goal` com movimentos fora de ordem → `movements` ordenados por (data, id); `withMovement`/`withoutMovement` devolvem instâncias novas (original intacta); `withoutMovement('inexistente')` → igual à original.
- Round-trip de `Goal` com e sem `targetDate` e com 2 movimentos (um com nota); `fromMap` sem `movements`/`archived` → `[]`/`false`; movimento inválido (sem `amountCents`) ignorado; `copyWith(targetDate: null)` limpa.
- `reservedByAccount` ignora arquivada e omite conta com 0; meta com `rawReservedCents < 0` (dado corrompido) → `reservedCents == 0`.

### T-123 · Posso gastar hoje (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/forecast/domain/spendable.dart` (novo), `test/features/forecast/spendable_test.dart` (novo)
contrato: SPEC §5.23 inteiro (`SpendableToday`, `spendableToday`, regras 1–9). Dart puro; usa `occurrencesBetween` (§5.4), `YearMonth`, `ForecastEvent`/`ForecastEventKind`; diferença de dias por `DateTime.utc(y, m, d)`. Não importa `goals/` (recebe `reservedByAccount` pronto).
aceite (a `Forecast` é montada com `ForecastService.compute(..., today: hoje, months: 6, minDays: 60)` sobre os dados do teste; `horizonEnd = ForecastService.horizonEnd(today: hoje, months: 6, minDays: 60)`):
- O exemplo completo de §5.23 com hoje 15/11/2026 (datas sugeridas: K1 fecha 28/vence 5 com compra de 80000 em 10/11 → vence 05/12; K2 fecha 3/vence 10 com compra de 120000 em 05/11 → vence 10/12; ambos com `paymentAccountId` A): `nextIncomeDate` 05/12, `days` 20, faturas 80000 (1 evento), provisionados 180000 (3 eventos: atrasado de B em 15/11, boleto 20/11, aluguel 01/12), reservas 40000, `freeCents` 50000, `perDayCents` 2500; transferência fora; conta C arquivada fora.
- Variações de §5.23: sem salário (até 30/11, 16 dias, livre 280000, 17500/dia); reserva 400000 (efetiva 300000, livre −210000, `overcommitted`, 0/dia); hoje 30/11 sem salário → `days == 1`; hoje 04/12 → `days == 1`; hoje 05/12 → `nextIncomeDate` 05/01/2027.
- Recorrência de receita inativa, em cartão, sem conta ou em conta arquivada não define a data (cai no fim do mês).
- Duas receitas (dia 5 'Salário' e dia 20 'Freela') com hoje 15/11 → 20/11, descrição 'Freela', `days` 5.
- Fatura vencida (vencimento 10/11, em aberto 30000) entra com evento em 15/11; fatura quitada não entra.
- `freeCents` de 1 centavo e `days` 20 → `perDayCents == 0` (arredonda para baixo, sem `double`).
- Conta de investimento não arquivada com saldo 500000 e meta de 100000 nela: não entra em `balanceCents` nem nas reservas (resultado igual ao exemplo completo).

### T-124 · `resolveCategoryByName` com subcategorias · `done` · deps: T-120 · parallel: yes
files: `lib/features/importing/domain/merchant_dictionary.dart`, `test/features/importing/merchant_dictionary_test.dart`
contrato: SPEC §5.13 `resolveCategoryByName` (passos 1–3 da Fase 10) e §4.8 (nota da Fase 10). Assinatura inalterada.
aceite (categorias: `defaultCategories()` + `mer2` 'Mercado' expense filha de `cat_alimentacao`, `out1` 'Outros' filha de `cat_alimentacao`, `out2` 'Outros' filha de `cat_transporte`):
- Testes existentes passam (sem subcategorias o resultado não muda).
- `'Alimentação › Mercado'` → `mer2`; `'alimentacao > mercado'` → `mer2`; `'Mercado'` → `cat_mercado` (raiz vence a filha homônima).
- `'Outros'` → `null` (2 filhas homônimas, sem raiz); `'Transporte › Outros'` → `out2`; `'Transporte › Inexistente'` → resolve `'Inexistente'` → `null`.
- Sem a raiz `cat_mercado` na lista: `'Mercado'` → `mer2` (única candidata).
- `'Combustível'` continua → `cat_transporte` (fallback).

### T-125 · Regras com tags: entidade e motor · `done` · deps: T-121 · parallel: yes
files: `lib/features/rules/domain/transaction_rule.dart`, `lib/features/rules/domain/rule_engine.dart`, `test/features/rules/rule_engine_test.dart`
contrato: SPEC §4.6 (bloco Fase 10: `tags`, construtor `const` com `this.tags = const []`, `fromMap` com `normalizeTags`, `toMap` só não vazia, `copyWith`, `==`/`hashCode`) e §5.14 (parágrafo "Tags (Fase 10)" de `reapplyRules`).
aceite:
- Round-trip de regra com tags; `fromMap` sem `'tags'` → `[]`; `fromMap` com `'tags': [' #a', 'A', 'b']` → `['a', 'b']`.
- `reapplyRules`: regra contains 'UBER' com tags `['transporte']` e outra contains 'TRIP' com `['viagem']` sobre `'UBER *TRIP'` sem tags → tags `['transporte', 'viagem']`; transação que já tem `['Transporte', 'viagem']` → não muda (fora do retorno); regra só com tags (sem categoria/renomear) muda só as tags.
- Idempotente: aplicar de novo sobre o resultado → `[]`.
- Testes existentes de regras passam.

### T-126 · Ledger, persistência e `AppServices` da Fase 10 · `done` · deps: T-120, T-121, T-122, T-123 · parallel: yes
files: `lib/app/bootstrap.dart`, `lib/app/app_scope.dart`, `lib/app/ledger.dart`, `test/app/ledger_goals_test.dart` (novo)
contrato: SPEC §3.5 (box `fm_goals`), §6.1 (`goals` obrigatório em `AppServices`), §6.2 bloco Fase 10 (`goals` opcional no `Ledger`, entra em `_sources`; `categoryTree`, `rolledSpendingFor`, `reservedByAccount`, `spendableToday`, `allTags`, todos memoizados e zerados em `_clearCache`).
aceite:
- `bootstrap(storeFactory: memória)` → `services.goals.all` vazio; `goals.upsert(meta)` notifica o `Ledger`.
- `identical(ledger.categoryTree, ledger.categoryTree)`; após `categories.upsert` de uma filha, `categoryTree.label(id)` contém ' › ' e `rolledSpendingFor(mês)` agrega o gasto dela no pai.
- `reservedByAccount` reflete aporte gravado; `spendableToday.reservedCents` muda depois de `goals.upsert(meta.withMovement(...))`; `identical(ledger.spendableToday, ledger.spendableToday)` sem mudança entre as leituras.
- `spendableToday.balanceCents == ledger.forecast.currentTotalCents`.
- `allTags` com 3 transações (`['Viagem']`, `['viagem', 'casa']`, `[]`) → `['Viagem', 'casa']`.
- `test/app/ledger_test.dart` (Ledger sem `goals`) passa sem mudança; `reservedByAccount` sem `goals` → `{}`.

### T-127 · Widgets de tag: `TagField`, `TagChips`, `showBulkTagsDialog` · `done` · deps: T-121 · parallel: yes
files: `lib/features/transactions/presentation/tag_widgets.dart` (novo), `test/features/transactions/tag_widgets_test.dart` (novo)
contrato: SPEC §7.3 Fase 10, bloco **Tags** (`TagField`, `TagChips`, `BulkTagsChoice`, `showBulkTagsDialog`). Cores via `context.colors`; sem `withOpacity`.
aceite:
- `TagField(tags: [])`: digitar 'viagem, Casa' + Enter → `onChanged(['viagem', 'Casa'])` e campo limpo; com `tags: ['viagem']`, digitar 'VIAGEM' + Enter → `onChanged(['viagem'])`.
- Tocar no X de um chip → `onChanged` sem ela; Backspace com campo vazio remove a última.
- `suggestions: ['viagem', 'trabalho', 'casa']` com `tags: ['casa']` e texto 'tr' → só o chip 'trabalho'; tocar → `onChanged(['casa', 'trabalho'])`.
- `TagChips(tags: ['a', 'b', 'c', 'd'])` → '#a', '#b', '#c', '+1'; `tags: []` → nada renderizado.
- `showBulkTagsDialog(count: 3, ...)` → título 'Tags em 3 transações'; 'Aplicar' desabilitado sem tags; adicionar 'x' e Aplicar → `(remove: false, tags: ['x'])`; modo 'Remover' → `remove: true`; Cancelar → `null`.

### T-128 · Categorizador e importação com tags · `done` · deps: T-125 · parallel: yes
files: `lib/features/importing/domain/categorizer.dart`, `lib/features/importing/domain/import_session.dart`, `test/features/importing/categorizer_test.dart`, `test/features/importing/import_session_test.dart`
contrato: SPEC §5.13 (`CategorizationResult.tags`, tags calculadas no passo 1 da cascata) e §5.16 (bullet "Tags (Fase 10)" do plano).
aceite:
- Regras contains 'UBER' (`cat_transporte`, tags `['app']`) prio 0 e contains 'TRIP' (só tags `['viagem']`) prio 1: `categorize('UBER *TRIP')` → `cat_transporte`, tags `['app', 'viagem']`; descrição que não casa regra (cai no dicionário) → tags `[]`.
- Plano: linha que casa regra com tags `['app']` → transação criada com `['app']`; parcela 3/10 → as 8 do grupo com `['app']`; casamento com provisionado que já tem `['x']` → `update` com `['x', 'app']`.
- `recategorize` com regra nova com tags muda as tags sugeridas das linhas não editadas.
- Testes existentes passam (incluindo desempenho).

### T-129 · Backup e "apagar dados" cobrem a Fase 10 · `done` · deps: T-126 · parallel: yes
files: `lib/core/services/backup_service.dart`, `lib/features/settings/presentation/settings_page.dart`, `test/core/backup_service_test.dart`, `test/features/settings/settings_page_test.dart`
contrato: SPEC §3.5 "Fase 10: `fm_goals` e campos novos" (chave `goals`, versão 1, ausência → `[]`, meta com conta ausente descartada, retrato/restauração, apagar dados, CSV com rótulo de categoria e coluna "Tags").
aceite:
- Export → import em app vazio devolve metas (com movimentos), `parentId` de categoria, tags de transação e tags de regra iguais.
- Backup sem `'goals'` → metas vazias; meta com `accountId` inexistente no backup some.
- Falha na gravação (store que lança uma vez em `fm_goals`) restaura as metas anteriores (padrão do teste de rollback existente).
- `transactionsCsv`: cabeçalho termina em 'Tags'; transação em subcategoria → 'Alimentação › Mercado'; tags `['a', 'b']` → 'a, b'.
- Ajustes Ultra → "Apagar todos os dados" confirmado → metas vazias.

### T-130 · Painel: card "Posso gastar hoje" · `done` · deps: T-126 · parallel: yes
files: `lib/features/dashboard/presentation/spendable_card.dart` (novo), `lib/features/dashboard/presentation/dashboard_page.dart`, `test/features/dashboard/spendable_card_test.dart` (novo)
contrato: SPEC §7.3 Fase 10, bloco **`SpendableCard`** e linha da tabela. `_DashboardBody` recebe `SpendableToday spendable` (de `s.ledger.spendableToday`) e põe `SpendableCard(data: spendable, ultra: ultra)` como **primeiro** filho, antes de `DashboardKpiRow`, seguido de `_gap`.
aceite (widget test com `SpendableToday` montado à mão dentro do app de teste; e um teste do Painel inteiro com seed):
- livre 50000, 2500/dia, até 05/12, receita 'Salário', 20 dias → textos 'R$ 500,00', ' livres · ', 'R$ 25,00', '/dia até 05/12' e 'Próxima receita: Salário em 05/12 (20 dias)'.
- 'Ver cálculo' → aparecem 'Saldo das contas', '− Faturas até 05/12 (1)', '− Provisionados até 05/12 (3)', '− Reservado em metas', '= Livre', '÷ 20 dias'; 'Ocultar cálculo' esconde.
- Ultra com detalhe aberto mostra a descrição de um evento de fatura; Simples não mostra descrições de eventos.
- livre −210000 → 'Sem folga até 05/12' e 'Faltam' + 'R$ 2.100,00'; nenhum '/dia'.
- Sem receita → 'Sem receita recorrente: considerando até o fim do mês (16 dias)'.
- `hideValues: true` → 'R$ ••••' no lugar dos valores.
- Painel com seed (Simples e Ultra): `find.byKey(ValueKey('spendable-card'))` existe e fica acima do primeiro `KpiTile` (`tester.getTopLeft(...).dy` menor).

### T-131 · Painel Ultra: drill-down por categoria · `done` · deps: T-126 · parallel: yes
files: `lib/features/dashboard/presentation/dashboard_summary.dart`, `lib/features/dashboard/presentation/dashboard_sections.dart`, `test/features/dashboard/dashboard_categories_test.dart` (novo)
contrato: SPEC §7.3 Fase 10, parágrafo **Drill-down do Painel (Ultra)** (`CategoryRow.id`/`children`, `rolledSpendingFor`, `CategoriesCard` stateful, keys).
aceite (app de teste; categorias padrão + 'Mercado X' filha de 'Alimentação'; despesas pagas no mês: 10000 direto em Alimentação, 50000 em Mercado X, 3000 em Transporte):
- `DashboardSummary.of(ledger, ultra: true).categories.first` → nome 'Alimentação', 60000, `children` = ['Mercado X' 50000, 'Sem subcategoria' 10000].
- Simples: 'Alimentação' com 60000 e `children` vazio; nenhum chevron.
- Ultra: filha invisível até tocar em `category-row-<id de Alimentação>`; depois `category-child-<id de Mercado X>` visível; tocar de novo esconde.
- Testes existentes do Painel passam.

### T-132 · Categorias: árvore, categoria pai e exclusão · `done` · deps: T-126 · parallel: yes
files: `lib/features/categories/presentation/categories_page.dart`, `lib/features/categories/presentation/category_form.dart`, `test/features/categories/categories_page_test.dart`
contrato: SPEC §7.3 Fase 10 (linhas "Árvore de categorias" e "Categoria pai" da tabela; parágrafo **Categorias**), §5.6 (`budgetStatuses(..., tree: ledger.categoryTree)`; gasto da raiz por `rolledSpendingFor`), §6.3 "Excluir categoria (Fase 10)". `_txWithoutCategory` passa a ser `t.copyWith(categoryId: null)` (preserva tags e campos de importação).
aceite:
- Criar 'Mercado X' com pai 'Alimentação' pelo form (`category-parent`) → `parentId` gravado; nova subcategoria criada pelo menu 'Nova subcategoria' herda ícone e cor do pai.
- Simples: 'Mercado X' aparece recuada logo abaixo de 'Alimentação'; gasto da raiz = agregado.
- Ultra: filha oculta até tocar em `category-toggle-<id>`; barra de orçamento da raiz usa o gasto agregado (orçamento 100000, gastos 10000 direto + 50000 na filha → `LimitBar` com usado 60000).
- Editar 'Alimentação' (com filha): campo pai desabilitado com 'Tem subcategorias'. Categorias de receita não aparecem como pai de despesa.
- Excluir 'Alimentação' com filha → SnackBar 'Mova ou exclua as subcategorias antes' e nada apagado; excluir uma categoria usada por transação com tags → transação sem categoria e com as tags intactas.
- Testes existentes passam.

### T-133 · Metas: diálogos (form, movimento, histórico) · `done` · deps: T-126 · parallel: yes
files: `lib/features/goals/presentation/goal_dialogs.dart` (novo), `test/features/goals/goal_dialogs_test.dart` (novo)
contrato: SPEC §7.3 Fase 10, bloco **Metas** (`showGoalForm`, `showGoalMovementDialog`, `showGoalHistory`; regras do form, movimento e histórico), §6.3 "Metas". Saldo da conta = `ledger.accountBalances[accountId] ?? 0`; metas de `services.goals.all`. Gravação com `goals.upsert`. `DropdownButtonFormField` com `initialValue`.
aceite (app de teste com 'Conta Alfa' saldo inicial 200000 e conta arquivada 'Conta Velha'):
- Form: nome vazio → 'Informe o nome'; alvo 0 → 'Informe um alvo maior que zero'; dropdown sem 'Conta Velha'; salvar 'Viagem' alvo 'R$ 6.000,00' sem data → meta gravada com `targetCents 600000`, `targetDate null`, e devolvida.
- Editar meta com movimentos → campo conta desabilitado com 'Meta com movimentos'.
- Movimento: aporte 'R$ 1.500,00' → `reservedCents 150000`; novo aporte 'R$ 600,00' → erro 'Saldo livre na conta: R$ 500,00' e nada gravado; retirada 'R$ 2.000,00' → 'Reservado nesta meta: R$ 1.500,00'; retirada 'R$ 500,00' → `reservedCents 100000`.
- Histórico: lista os 2 movimentos (mais recente primeiro); excluir o aporte de 150000 (com a retirada de 50000 ainda lá) → SnackBar 'Sem este aporte, as retiradas ficariam maiores que o reservado' e nada muda; excluir a retirada → `reservedCents 150000`.
- Nenhuma ação cria transação (`transactions.all` inalterado).

### T-134 · Metas: seção em Contas · `done` · deps: T-133 · parallel: yes (com T-137)
files: `lib/features/goals/presentation/goals_section.dart` (novo), `lib/features/accounts/presentation/accounts_page.dart`, `test/features/goals/goals_section_test.dart` (novo)
contrato: SPEC §7.3 Fase 10 (linhas "Metas" e "Reservado por conta" da tabela; bloco **Metas**: `GoalsSection`, linha, Ultra/Simples, estado vazio), §6.3 (excluir/arquivar meta; "Excluir conta (Fase 10)"). `AccountsPage` põe `const GoalsSection()` depois da lista de contas (`AppSpace.lg` antes); linha da conta no Ultra mostra 'R$ X reservado' (de `ledger.reservedByAccount`), em `warning` se `overReservedCents > 0`. `_delete` inclui metas no `inUse` e troca a mensagem.
aceite (app de teste com 'Conta Alfa' saldo 200000):
- Sem metas → `EmptyState` com 'Nova meta'; sem conta ativa → botão 'Nova meta' desabilitado.
- Meta alvo 600000 com 120000 reservado: Simples mostra nome, 'R$ 1.200,00', 'R$ 6.000,00', '20,0%' e o botão 'Aportar'; sem menu nem 'Aporte mensal necessário'.
- Ultra com data-alvo 15/05/2027 (hoje 15/11/2026) → 'Aporte mensal necessário: R$ 800,00'; data 10/10/2026 → 'Data-alvo passou'; alvo atingido → 'Meta atingida'.
- Ultra: gasto pago que derruba o saldo para 80000 → badge 'Reserva acima do saldo: faltam R$ 400,00' e caption da conta em `warning`.
- Arquivar (menu) → some da lista; 'Mostrar arquivadas' → reaparece em `textSecondary`. Excluir com confirmação → removida.
- Excluir 'Conta Alfa' (sem transações) com uma meta → SnackBar 'Conta usada por lançamentos, cartões, recorrências ou metas. Arquive em vez de excluir.'
- Smoke test e testes existentes de Contas passam.

### T-135 · Rótulo 'Pai › Filha': recorrência e prévia de importação · `done` · deps: T-126 · parallel: yes
files: `lib/features/recurring/presentation/recurring_form.dart`, `lib/features/importing/presentation/import_preview_page.dart`, `lib/features/importing/presentation/import_preview_row.dart`, `test/features/recurring/recurring_form_test.dart`
contrato: SPEC §7.3 Fase 10 (rótulo e ordem de dropdown via `ledger.categoryTree`). `recurring_form.dart`: itens de categoria = `categoryTree.options(kind)` com texto `categoryTree.label(id)`. `ImportPreviewRow` ganha `String Function(TransactionCategory c)? labelOf` (padrão `c.name`) usado nos itens do dropdown; `import_preview_page.dart` passa `categoryOptions` = `categoryTree.options(kind da linha)` e `labelOf: (c) => tree.label(c.id)`.
aceite:
- Form de recorrência com 'Mercado X' filha de 'Alimentação' → item 'Alimentação › Mercado X' logo depois de 'Alimentação'; escolher grava o id da filha.
- Testes existentes de recorrência e de prévia passam.

### T-136 · Rótulo 'Pai › Filha': dicionário e detalhe do cartão · `done` · deps: T-124, T-126 · parallel: yes
files: `lib/features/importing/presentation/dictionary_section.dart`, `lib/features/cards/presentation/card_detail_page.dart`, `test/features/importing/dictionary_section_test.dart`
contrato: SPEC §4.8 (nota Fase 10: o form grava `categoryTree.label(id)` como `categoryName`), §5.13 (`resolveCategoryByName` com caminho), §7.3 Fase 10 (rótulo). Dicionário: dropdown com `options(expense)` + `options(income)` e texto `label`; badge 'Categoria não encontrada' continua via `resolveCategoryByName`; editar entrada com caminho seleciona a filha. `card_detail_page.dart`: `categoryName: tree.label(id)` (vazio → null).
aceite:
- Novo padrão 'loja x' com categoria 'Alimentação › Mercado X' → `categoryName 'Alimentação › Mercado X'`; a linha não mostra 'Categoria não encontrada'.
- Entrada com `categoryName 'Alimentação › Inexistente'` → 'Categoria não encontrada'.
- Testes existentes passam.

### T-137 · Form de transação: categoria em árvore e tags · `done` · deps: T-126, T-127, T-128 · parallel: yes (com T-134)
files: `lib/features/transactions/presentation/transaction_form.dart`, `test/features/transactions/transaction_form_test.dart`
contrato: SPEC §4.4 (recriar pelo construtor passa `tags`), §7.3 Fase 10 (linha "Tags no form de transação"; parágrafo "Form de transação (Ultra)"). `_categoriesFor` passa a ser `ledger.categoryTree.options(kind)` com texto `label`. Estado `List<String> _tags = initial?.tags ?? const []`, `bool _tagsTouched = false`, `bool _tagsFromRule = false`. Ultra: `TagField(tags: _tags, suggestions: ledger.allTags, helperText: _tagsFromRule ? 'Tags da regra' : null, onChanged: (v) => setState(() { _tags = v; _tagsTouched = true; _tagsFromRule = false; }))` depois da Categoria. No gatilho de descrição existente, se `initial == null && !_tagsTouched` e tipo expense/income → `_tags = r.tags; _tagsFromRule = r.tags.isNotEmpty` (mesmo se a categoria já foi escolhida). `Transaction(..., tags: _tags)`; compra parcelada leva as tags (via `buildInstallments`).
aceite:
- Editar transação com tags `['viagem']` e só mudar o valor (Simples e Ultra) → tags preservadas; Simples não mostra o campo Tags.
- Ultra, nova despesa: digitar tag 'trabalho' + Enter e salvar → transação com `['trabalho']`.
- Ultra, com regra contains 'UBER' tags `['app']`: nova despesa, digitar 'UBER TRIP' → chip 'app' e 'Tags da regra'; salvar → `['app']`. Mexer nas tags antes de digitar a descrição → a regra não sobrescreve.
- Dropdown de categoria mostra 'Alimentação › Mercado X' depois de 'Alimentação'.
- Parcelado em 3x com tags `['x']` → 3 parcelas com `['x']`.
- Testes existentes passam.

### T-138 · Regras: tags no form e na seção · `done` · deps: T-125, T-126, T-127 · parallel: yes
files: `lib/features/rules/presentation/rule_form.dart`, `lib/features/rules/presentation/rules_section.dart`, `test/features/rules/rules_section_test.dart`
contrato: SPEC §4.6 (regra útil inclui tags), §7.3 Fase 10 (linha "Tags em regras"), §5.14 (tags no reaplicar). Form: `TagField(label: 'Adicionar tags', suggestions: ledger.allTags)` depois de 'Renomear para'; grava `tags: normalizeTags(_tags)`; erro passa a 'Defina categoria, renomeação ou tags'; dropdown de categoria por `categoryTree.options` + `label`. Seção: `TagChips(tags: rule.tags)` na linha; rótulo da categoria por `label`. Reaplicar: texto `'N transações vão mudar (X de categoria, Y de descrição, Z de tags)'` (Z = mudadas cujas tags diferem da original).
aceite:
- Regra só com tags `['app']` (sem categoria/renomear) salva; sem nada → 'Defina categoria, renomeação ou tags'.
- Linha da regra mostra '#app'.
- Reaplicar com 2 transações que casam e sem a tag → '2 transações vão mudar (0 de categoria, 0 de descrição, 2 de tags)'; Aplicar → as 2 com `['app']`.
- Testes existentes passam (ajustar só o texto do reaplicar onde algum teste o compara).

### T-139 · Transações: subcategorias, filtro de tags e tags na linha · `done` · deps: T-115 (Fase 9 fechada), T-126, T-127 · parallel: yes (com T-140)
files: `lib/features/transactions/presentation/transaction_filters.dart`, `lib/features/transactions/presentation/transactions_page.dart`, `lib/features/transactions/presentation/transaction_row.dart`, `test/features/transactions/transactions_tags_test.dart` (novo)
contrato: SPEC §7.3 Fase 10, parágrafo "Transações (Ultra)" (`TransactionFilter.tags` + `copyWith(tags:)`, `hasCriteria`, `query` casando tags, `matches(t, {CategoryTree? tree})`, `visibleTransactions(..., {tree})`, dropdown de categoria por `options`/`label`, botão `filter-tags`, rótulo por `label`, `TagChips` na linha Ultra, ordenação por rótulo). `TransactionRow` ganha `String? categoryLabel` (não nulo → usado no lugar de `category.name`) e mostra `TagChips` só no Ultra. A página passa `tree: ledger.categoryTree` para `visibleTransactions` e o rótulo para a linha e para a ordenação.
aceite (seed demo, Ultra, 1400×900; 'Mercado X' filha de 'Alimentação'; transações do mês: A em 'Alimentação', B em 'Mercado X' com tags `['viagem']`, C em 'Transporte' com `['Trabalho']`):
- Filtro de categoria 'Alimentação' → A e B visíveis, C não; 'Alimentação › Mercado X' → só B.
- `filter-tags` → marcar 'viagem' → só B; marcar também 'Trabalho' → B e C ('Tags (2)'); 'Limpar tags' → todas.
- Busca 'trabalho' → C (casa a tag).
- Linha de B mostra 'Alimentação › Mercado X' e '#viagem'; Simples não mostra '#viagem'.
- Testes existentes de Transações (incluindo os da Fase 9 e `transaction_filters_test.dart`) passam.

### T-140 · Paleta: busca por tag e rótulo de subcategoria · `done` · deps: T-115 (Fase 9 fechada), T-121, T-126 · parallel: yes (com T-139)
files: `lib/features/transactions/domain/transaction_search.dart`, `lib/app/app_commands.dart`, `test/features/transactions/transaction_search_test.dart`, `test/app/app_commands_test.dart`
contrato: SPEC §5.17 regra 5 (tags no índice, token `#`) e §7.3 Fase 10 (última frase do parágrafo "Transações (Ultra)": `subtitle` com rótulo e `' · #a #b'`). Tags pré-dobradas no construtor do índice (nada de `foldText` por transação em `search`).
aceite:
- Exemplos extras de §5.17 (Fase 10) com t1/t2 do SPEC acrescidos das tags indicadas; exemplos e desempenho antigos continuam passando.
- `transactionEntries` com transação em 'Mercado X' (filha de 'Compras') e tags `['casa']` → subtitle '14/11/2026 · Cartão Beta · Compras › Mercado X · #casa'.
- Testes existentes passam.

### T-141 · Ações em massa: 'Tags' e rótulos em diálogos e célula inline · `done` · deps: T-139, T-127 · parallel: no
files: `lib/features/transactions/presentation/transactions_page.dart`, `lib/features/transactions/presentation/bulk_dialogs.dart`, `lib/features/transactions/presentation/inline_cells.dart`, `test/features/transactions/transactions_bulk_tags_test.dart` (novo)
contrato: SPEC §6.3 "Tags em massa (Fase 10)", §7.3 Fase 10 (`BulkAction('Tags', Icons.sell_outlined)` depois de 'Recategorizar'; `labelOf` em `InlineCategoryCell` e `showBulkCategoryDialog`, com a ordem recebida mantida). A página passa `options(kind)` + `labelOf: (c) => tree.label(c.id)` para as células inline e para o diálogo de recategorizar (lista = `options(expense)` + `options(income)`). `bulk_action_bar.dart` não muda.
aceite (seed demo, Ultra, 1400×900):
- Selecionar 2 transações → 'Tags' → adicionar 'viagem' → as 2 com 'viagem' no repositório; SnackBar 'Tags atualizadas em 2 transações'; seleção mantida.
- Modo 'Remover' 'viagem' nas mesmas → tags removidas; transação que não tinha a tag não entra na contagem.
- Célula inline de categoria lista 'Alimentação › Mercado X'; diálogo 'Recategorizar' também.
- Testes existentes da Fase 9 (`bulk_dialogs_test.dart`, `inline_cells_test.dart`, `transactions_bulk_test.dart`) passam sem mudança (parâmetro novo é opcional).

### T-142 · Documentação da Fase 10 · `done` · deps: T-120..T-141 · parallel: no
files: `CONTEXT.md`, `ROADMAP.md`, `docs/BACKLOG.md`
contrato: CONTEXT §4 (árvore com `features/goals/`, `category_tree.dart`, `tags.dart`, `spendable.dart`, `goal_math.dart`, `spendable_card.dart`, `tag_widgets.dart`, `goals_section.dart`, `goal_dialogs.dart`), §5 (Painel com "Posso gastar hoje" como 1º elemento e drill-down; Categorias em árvore; Metas em Contas; tags em Transações, form, regras, paleta e massa; diferenças Simples/Ultra), §6 (regras de "posso gastar", orçamento do pai, reserva de metas), §7 (box `fm_goals`; backup cobre metas, `parentId` e tags; CSV com coluna Tags), §8 (testes novos, total), §10 (commit), §11 (status), §12 (limites: receitas provisionadas avulsas não definem a próxima receita nem somam no livre; contas de investimento entram no saldo do "posso gastar"; recorrências não carregam tags; tags só editáveis no Ultra; subcategorias homônimas tornam o nome simples ambíguo no dicionário/CSV; reserva acima do saldo só gera aviso). ROADMAP: Fase 10 em "v3". BACKLOG: T-120..T-141 `done`.
aceite: total de testes igual ao de `flutter test`; `bash tool/check.sh` → `CHECK OK`.

### Pendências da revisão da Fase 10 · `todo`
- Recorrências não têm tags e a materialização não aplica regras: ocorrências recorrentes nunca recebem tags.
- `hasAnyTag` dobra as tags a cada build de Transações (O(n·tags)); pré-dobrar chaves ou indexar no Ledger se pesar.

## Fase 11 — Patrimônio e devo/me devem

> Origem: `docs/V3_DIRECTION.md` (Domínios novos: Patrimônio; Devo / me devem). Contratos: SPEC §3.5 (Fase 11), §4.10, §4.11, §5.7 (extras), §5.23 regra 6 (nota Fase 11), §5.24–5.26, §6.1–6.3 (Fase 11), §7.3 "Patrimônio e devo/me devem (Fase 11)", §8.
> Sem dependência nova (`fl_chart` já existe). Domínio puro primeiro, com os exemplos do SPEC como teste; Ledger/persistência; UI por último.
> Decisões fechadas: patrimônio = contas não arquivadas (todos os tipos) + ativos manuais (último snapshot até a data) + a receber − a pagar − dívida de cartão. **Dívida de cartão = saldo devedor já contratado** (compras lançadas inclusive parcelas futuras de compras já feitas − estornos − pagamentos de fatura; sem recorrências projetadas), por data de compra (`cardPurchaseDate`). Histórico de 24 meses memoizado no Ledger; pontos no fim de cada mês e o último em hoje. Ativo: 1 snapshot por data, só data ≤ hoje, "Encerrar" = snapshot 0 + arquivado (histórico mantido). Dívida: pagamentos parciais com histórico; "quitado" é derivado (restante 0); cada pagamento cria transação paga (receita se me devem, despesa se devo; categoria opcional) e guarda o id; desfazer exclui a transação; dívida com pagamentos não pode ser excluída nem mudar de direção. "Devo" com vencimento entra na Previsão e no "posso gastar" como evento `expense` sem conta (via `extraEvents`; `spendable.dart` não muda); "me devem" nunca entra. Página nova **Patrimônio** (índice 9, na sidebar depois de Contas, sem atalho numérico; atalhos 1–9 intactos); Painel Ultra ganha o KPI 'Patrimônio líquido'. Simples: KPI + linha de apoio, ativos e dívidas enxutos.
> Dependência da Fase 10: T-154, T-155, T-159 e T-163 tocam arquivos da Fase 10 (`ledger.dart`, `bootstrap.dart`, `app_scope.dart`, `backup_service.dart`, `settings_page.dart`, `dashboard_summary.dart`, `dashboard_sections.dart`, `app_commands.dart`) → só começam com a revisão da Fase 10 fechada (T-142 `done`). As ondas A, B e T-158 só criam arquivos novos (e `forecast.dart`, que a Fase 10 não tocou) e podem começar antes.
> Ondas (tarefas da mesma onda têm arquivos disjuntos): **A** T-150, T-151, T-152 · **B** T-153 · **C** (Fase 10 fechada) T-154, T-158 · **D** T-155, T-156, T-157, T-159 · **E** T-160, T-161 · **F** T-162 · **G** T-163 · **H** T-164.
> Datas nos testes: `DateTime(2026, 11, 15)` como "hoje" (salvo indicação). App de teste igual a `test/features/goals/goals_section_test.dart` (`bootstrap` em memória, `clock`).

### T-150 · Ativos: entidade `Asset` e regras de snapshot (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/net_worth/domain/asset.dart` (novo), `test/features/net_worth/asset_test.dart` (novo)
contrato: SPEC §4.10 inteiro (`AssetKind`, `assetKindLabel`, `AssetSnapshot`, `Asset`) e §5.24 inteiro (`assetSnapshotError`, `removeSnapshotError`, `closeAsset`, `assetsValueAt`, regras 1–5). Dart puro; datas com `dateOnly`/`dateKey`/`parseDateKey`; nada de `package:flutter`.
aceite:
- Todos os exemplos de §5.24.
- Construtor com snapshots fora de ordem → ordenados por data; dois na mesma data → fica o último da lista recebida; lista imutável (`add` lança).
- `withSnapshot`/`withoutSnapshot` devolvem instâncias novas (original intacta); `withoutSnapshot('inexistente')` → igual à original.
- Round-trip de `Asset` com 2 snapshots (um com nota) e `archived: true`; `fromMap` sem `snapshots`/`archived` → `[]`/`false`; `kind` desconhecido → `investment`; snapshot inválido (sem `valueCents`) ignorado.
- `assetKindLabel` dos 4 tipos; `lastChangeCents` com 1 snapshot → `null`; sem snapshots: `currentValueCents == 0`, `latest == null`.

### T-151 · Devo / me devem: entidade `Debt` e regras (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/debts/domain/debt.dart` (novo), `lib/features/debts/domain/debt_math.dart` (novo), `test/features/debts/debt_test.dart` (novo)
contrato: SPEC §4.11 inteiro (`DebtDirection`, `DebtPayment`, `Debt`) e §5.25 inteiro (`debtPaymentError`, `debtTransactionDescription`, `settleDebt`, `undoDebtPayment`, `isDebtOverdue`, `debtTotalsAt`, `debtForecastEvents`, `PersonDebtSummary`, `debtsByPerson`, `debtPeople`, regras 1–7). Dart puro; mensagens com `formatMoney`; agrupamento com `foldText(person.trim())`; importa `Transaction` (§4.4) e `ForecastEvent`/`ForecastEventKind` de `forecast.dart` (sem mudar `forecast.dart`).
aceite:
- Todos os exemplos de §5.25, exceto o de "posso gastar" (fica em T-154).
- `Debt(person: '  Ana ', description: '  ')` → `person 'Ana'`, `description null`; pagamentos fora de ordem → ordenados por (data, id); lista imutável.
- Round-trip com e sem `description`/`dueDate` e com 2 pagamentos (um sem `transactionId`); `fromMap` sem `payments` → `[]`; `direction` desconhecida → `iOwe`; `copyWith(dueDate: null)` limpa; omitido mantém.
- `settleDebt` em dívida `iOwe` → transação `expense` com 'Pago a Bruno'; categoria passada chega na transação.
- `debtForecastEvents`: evento com `kind == ForecastEventKind.expense`, `accountId == null`, `sourceId == debt.id`; dívida com descrição → 'Devo a Bruno · {descrição}'; pagamento parcial reduz o valor do evento para o restante.

### T-152 · Previsão aceita eventos extras · `done` · deps: — · parallel: yes
files: `lib/features/forecast/domain/forecast.dart`, `test/features/forecast_test.dart`
contrato: SPEC §5.7 (parâmetro `Iterable<ForecastEvent> extraEvents = const []` em `ForecastService.compute`; bullet "Extras (Fase 11)" do passo 3). Os extras entram em `events` antes da ordenação existente e seguem o mesmo caminho (meses, `daily`, `firstNegativeDate`; `accountNegativeDates` só se `accountId` não nulo). Nenhum chamador muda (parâmetro opcional).
aceite (hoje 15/11/2026, uma conta A com 100000, sem outras transações):
- Extra `expense` −30000 em 01/12 sem conta → `events` contém o evento em 01/12; `daily` de 01/12 em diante = 70000; `months[1].expenseCents` inclui 30000 (mesmo critério das despesas); `accountNegativeDates` vazio.
- Extra em 10/11 (passado) → entra com `date` 15/11; extra depois do fim do horizonte → ignorado.
- Extra de −150000 em 20/11 → `firstNegativeDate == 20/11/2026`.
- Sem `extraEvents` → resultado idêntico ao atual (testes existentes de previsão, linha do tempo e `spendable_test.dart` passam sem mudança).

### T-153 · Patrimônio líquido: histórico mensal e dívida de cartão (domínio) · `done` · deps: T-150, T-151 · parallel: yes
files: `lib/features/net_worth/domain/net_worth.dart` (novo), `test/features/net_worth/net_worth_test.dart` (novo)
contrato: SPEC §5.26 inteiro (`NetWorthPoint`, `cardPurchaseDate`, `cardDebtAt`, `netWorthHistory`, regras 1–5 e a decisão "Dívida de cartão"). Reusa `monthlyHistory` (§5.10) para `accountsCents`, `assetsValueAt` (§5.24) e `debtTotalsAt` (§5.25). Dart puro.
aceite (dados exatos do exemplo de §5.26; transações do cartão com `buildInstallments`):
- 3 pontos: set `netCents 4490000` (contas 600000, ativos 4000000, a receber 0, a pagar 80000, cartão 30000); out `4920000` (870000, 4200000, 50000, 80000, 120000); nov `4670000` (840000, 4000000, 30000, 80000, 120000).
- `date` dos pontos: 30/09/2026, 31/10/2026 e 15/11/2026; `history.last.accountsCents == ForecastService.compute(...).currentTotalCents` com os mesmos dados.
- Variações de §5.26: estorno → cartão de nov 110000; `invoicePayment` com data 20/11 → cartão 80000, contas 800000, líquido 4670000; pagamento maior que a dívida → 0; `cardPurchaseDate` → 28/01/2026.
- Cartão de débito com despesa paga → não entra em `cardDebtCents`; recorrência de cartão de crédito não materializada → não entra; cartão arquivado com saldo devedor → entra.
- `netWorthHistory(months: 24)` → 24 pontos em ordem cronológica, último no mês de hoje.

### T-154 · Ledger, persistência e `AppServices` da Fase 11 · `done` · deps: T-150, T-151, T-152, T-153, T-142 (Fase 10 fechada) · parallel: yes (com T-158)
files: `lib/app/bootstrap.dart`, `lib/app/app_scope.dart`, `lib/app/ledger.dart`, `test/app/ledger_net_worth_test.dart` (novo)
contrato: SPEC §3.5 (boxes `fm_assets`, `fm_debts`), §6.1 (`assets` e `debts` obrigatórios em `AppServices`), §6.2 bloco Fase 11 (`assets`/`debts` opcionais no `Ledger`, entram em `_sources`; `forecast` com `extraEvents: debtForecastEvents(...)`; `netWorthMonths = 24`; `netWorthHistory`, `debtsByPerson`, `debtPeople` memoizados e zerados em `_clearCache`).
aceite:
- `bootstrap(storeFactory: memória)` → `services.assets.all` e `services.debts.all` vazios; `assets.upsert` e `debts.upsert` notificam o `Ledger`.
- `ledger.netWorthHistory.length == 24`; `identical(ledger.netWorthHistory, ledger.netWorthHistory)`; após `assets.upsert` de um ativo com snapshot de hoje 100000, `netWorthHistory.last.assetsCents == 100000`.
- `netWorthHistory.last.accountsCents == ledger.forecast.currentTotalCents`.
- Exemplo de "posso gastar" de §5.25 (conta A 300000, salário dia 5, d2 devo 80000 vence 01/12, d5 'Eva' me deve 50000 vence 20/11) → `spendableToday.plannedCents == 80000`, `freeCents == 220000`, `perDayCents == 11000`; `forecast.events` tem 1 evento 'Devo a Bruno' e nenhum de 'Eva'.
- Registrar pagamento de 80000 em d2 (`debts.upsert(settleDebt(...).debt)`) → o evento some da previsão (cache invalidado).
- `debtsByPerson`/`debtPeople` refletem `debts.all`; `test/app/ledger_test.dart` e `ledger_goals_test.dart` (Ledger sem `assets`/`debts`) passam sem mudança; sem `debts` → `debtsByPerson == []`.

### T-155 · Backup e "apagar dados" cobrem ativos e dívidas · `done` · deps: T-154 · parallel: yes
files: `lib/core/services/backup_service.dart`, `lib/features/settings/presentation/settings_page.dart`, `test/core/backup_service_test.dart`, `test/features/settings/settings_page_test.dart`
contrato: SPEC §3.5 "Fase 11: `fm_assets` e `fm_debts`" (chaves `assets` e `debts`, versão 1, ausência → `[]`, sem validação de vínculo, retrato/restauração, apagar dados e nova mensagem de confirmação).
aceite:
- Export → import em app vazio devolve ativos (com snapshots e `archived`) e dívidas (com pagamentos e `transactionId`) iguais.
- Backup sem `'assets'`/`'debts'` → coleções vazias e o resto importa normalmente.
- Falha na gravação (store que lança uma vez em `fm_debts`) restaura ativos e dívidas anteriores (padrão do teste de rollback existente).
- Ajustes Ultra → "Apagar todos os dados" confirmado → ativos e dívidas vazios; a mensagem do diálogo menciona 'ativos, dívidas'.

### T-156 · Ativos: diálogos (form, atualizar valor, histórico) · `done` · deps: T-154 · parallel: yes
files: `lib/features/net_worth/presentation/asset_dialogs.dart` (novo), `test/features/net_worth/asset_dialogs_test.dart` (novo)
contrato: SPEC §7.3 Fase 11, bloco **Diálogos de ativo** (`showAssetForm`, `showAssetValueDialog`, `showAssetHistory`) e §6.3 "Ativos (Fase 11)". `DropdownButtonFormField` com `initialValue`; cores via `context.colors`; guarda contra duplo pop.
aceite:
- Form: nome vazio → 'Informe o nome'; valor vazio → 'Informe o valor'; criar 'Carro X' tipo 'Veículo' valor 'R$ 40.000,00' data padrão → ativo gravado com `kind vehicle`, 1 snapshot de 4000000 em 15/11/2026, e devolvido.
- Editar → sem campos de valor/data; trocar o nome grava só o nome (snapshots intactos).
- Atualizar valor: 'R$ 38.000,00' em 15/11 → `currentValueCents 3800000`; escolher a data de um snapshot existente mostra 'Substitui o valor de dd/mm/aaaa' e salvar mantém a quantidade de snapshots; data 16/11 → 'A data não pode ser no futuro' e nada gravado.
- Histórico: lista os snapshots do mais recente para o mais antigo com a variação; excluir com 2 snapshots → sobra 1; excluir o único → SnackBar 'O ativo precisa de pelo menos um valor' e nada muda.
- Nenhuma ação cria transação (`transactions.all` inalterado).

### T-157 · Dívidas: diálogos (form, quitar, pagamentos) · `done` · deps: T-154 · parallel: yes
files: `lib/features/debts/presentation/debt_dialogs.dart` (novo), `test/features/debts/debt_dialogs_test.dart` (novo)
contrato: SPEC §7.3 Fase 11, bloco **Diálogos de dívida** (`showDebtForm`, `showSettleDebtDialog`, `showDebtPayments`) e §6.3 "Dívidas (Fase 11)" (ordem de gravação transação → dívida, compensação, SnackBars, desfazer). `Autocomplete<String>` com `ledger.debtPeople`; dropdowns com `initialValue`; categoria por `ledger.categoryTree.options(kind)` + `label`.
aceite (app de teste com 'Conta Alfa' saldo 200000 e conta arquivada 'Conta Velha'):
- Form: pessoa vazia → 'Informe a pessoa'; valor 0 → 'Informe um valor maior que zero'; vencimento antes da data → 'Vencimento antes da data'; salvar 'Ana' 'Me devem' 'R$ 500,00' → dívida gravada com `owedToMe` e 50000.
- Pessoa: com uma dívida existente de 'Bruno', digitar 'bru' mostra a opção 'Bruno'.
- Editar dívida com pagamento de 20000: direção desabilitada com 'Dívida com pagamentos'; valor 'R$ 100,00' → 'Já pago: R$ 200,00'.
- Quitar: dropdown sem 'Conta Velha'; parcial 'R$ 200,00' → 1 transação `income` 20000 'Recebido de Ana' em 'Conta Alfa' (saldo da conta 220000), restante 30000, SnackBar 'Pagamento registrado · transação criada em Conta Alfa'; em seguida 'R$ 300,01' → 'Restante: R$ 300,00' e nada gravado; depois 'R$ 300,00' → `settled` e 'Dívida quitada · transação criada em Conta Alfa'.
- Dívida 'Devo' com categoria escolhida → transação `expense` com essa categoria.
- Pagamentos: 'Desfazer' com confirmação → pagamento removido e transação excluída; pagamento cuja transação foi apagada mostra 'Transação excluída' e desfazer só remove o pagamento.
- Sem conta ativa → 'Cadastre uma conta para registrar o pagamento.' e 'Confirmar' desabilitado.

### T-158 · Gráfico de evolução do patrimônio · `done` · deps: T-153 · parallel: yes (com T-154)
files: `lib/features/net_worth/presentation/net_worth_chart.dart` (novo), `test/features/net_worth/net_worth_chart_test.dart` (novo)
contrato: SPEC §7.3 Fase 11, bloco **`NetWorthChart`** (`NetWorthChart`, `netWorthTooltipText`; fl_chart como em `forecast_chart.dart`; tooltip rico da Fase 7). Cores via `context.colors`; sem gradiente.
aceite (pontos montados à mão):
- `netWorthTooltipText` do ponto de out/2026 de §5.26 → 'Outubro 2026\nPatrimônio líquido: R$ 49.200,00\nContas: R$ 8.700,00\nAtivos: R$ 42.000,00\nA receber: R$ 500,00\nA pagar: -R$ 800,00\nDívida de cartão: -R$ 1.200,00'.
- Ponto do mês atual (date 15/11, não é o último dia) → 1ª linha 'Novembro 2026 (até 15/11)'.
- `hideValues: true` → todos os valores 'R$ ••••'.
- Widget com 12 pontos renderiza um `LineChart` sem exceção; com 1 ponto → 'Ainda sem histórico para o gráfico.'; com um ponto negativo existe a linha horizontal em 0 (`extraLinesData.horizontalLines` não vazio).

### T-159 · Painel Ultra: KPI "Patrimônio líquido" · `done` · deps: T-154 · parallel: yes
files: `lib/features/dashboard/presentation/dashboard_summary.dart`, `lib/features/dashboard/presentation/dashboard_sections.dart`, `test/features/dashboard/dashboard_net_worth_test.dart` (novo)
contrato: SPEC §7.3 Fase 11, parágrafo **Painel Ultra** (`netWorthCents`, `netWorthDelta`, `netWorthTrend` em `DashboardSummary`; 6º `KpiTile` depois de 'Gasto no mês' com `_Trend(higherIsBetter: true)`).
aceite:
- Ultra com um ativo de 100000 (snapshot de hoje): `DashboardSummary.of(ledger, ultra: true).netWorthCents == ledger.netWorthHistory.last.netCents`; `netWorthTrend.length == 6`; o Painel mostra 'Patrimônio líquido'.
- Simples: os três campos `null` e o texto 'Patrimônio líquido' não aparece no Painel.
- Testes existentes do Painel (incluindo `spendable_card_test.dart` e `dashboard_categories_test.dart`) passam.

### T-160 · Patrimônio: seção de ativos · `done` · deps: T-156 · parallel: yes (com T-161)
files: `lib/features/net_worth/presentation/assets_section.dart` (novo), `test/features/net_worth/assets_section_test.dart` (novo)
contrato: SPEC §7.3 Fase 11 (linha "Ativos" da tabela; bloco **`AssetsSection`**), §6.3 "Ativos (Fase 11)" (encerrar, reativar, excluir com confirmação). Usa os diálogos de T-156.
aceite (app de teste; ativos 'Carro' 3800000 com 2 snapshots e 'Tesouro' 200000):
- Sem ativos → `EmptyState` com 'Novo ativo'.
- Simples: 'Carro' antes de 'Tesouro' (maior valor primeiro), 'Veículo', 'R$ 38.000,00' e o botão `asset-update-<id>`; sem menu.
- Ultra: 'Atualizado em 01/11/2026', variação '-R$ 2.000,00', rodapé 'Total' 'R$ 40.000,00'.
- Ultra: menu 'Encerrar' com confirmação → 'Carro' some, `assets-show-archived` aparece; marcar → 'Carro' volta com 'Encerrado'; 'Reativar' → `archived` false. 'Excluir' confirmado → removido do repositório.

### T-161 · Patrimônio: seção devo / me devem · `done` · deps: T-157 · parallel: yes (com T-160)
files: `lib/features/debts/presentation/debts_section.dart` (novo), `test/features/debts/debts_section_test.dart` (novo)
contrato: SPEC §7.3 Fase 11 (linha "Devo / me devem" da tabela; bloco **`DebtsSection`**: totais de `ledger.netWorthHistory.last`, 'Por pessoa' de `ledger.debtsByPerson`, filtros, ordem, keys), §6.3 "Dívidas (Fase 11)" (excluir bloqueado com pagamentos). Usa os diálogos de T-157.
aceite (app de teste com 'Conta Alfa'; dívidas d1 só com p1, d2, d3, d4 e d6 de §5.25):
- `debt-totals` mostra 'R$ 300,00' (me devem) e 'R$ 950,00' (devo).
- Simples: 4 linhas em aberto (Dani quitada fora), d3 com 'Vencida', d4 (sem vencimento) por último; sem filtros nem 'Por pessoa'.
- Ultra: 'Por pessoa' com Bruno, Ana, Carla nessa ordem; tocar em `debt-person-0` → só as dívidas de Bruno; filtro 'Me devem' → só d1; 'Mostrar quitadas' → Dani aparece com 'Quitada' e sem 'Quitar'.
- `debt-settle-<d2>` abre 'Pagar a Bruno'.
- Menu 'Excluir' em d1 (tem pagamento) → SnackBar 'Desfaça os pagamentos antes de excluir' e nada muda; em d4 confirmado → removida.
- Sem dívidas → `EmptyState` com 'Nova dívida'.

### T-162 · Página Patrimônio · `done` · deps: T-158, T-160, T-161 · parallel: no
files: `lib/features/net_worth/presentation/net_worth_page.dart` (novo), `test/features/net_worth/net_worth_page_test.dart` (novo)
contrato: SPEC §7.3 Fase 11 (tabela; bloco **`NetWorthPage`**: KPI com delta/sparkline no Ultra e linha de apoio no Simples, 'Evolução' com seletor 12/24, 'Composição' com variação da contribuição, `AssetsSection`, `DebtsSection`, botões do cabeçalho).
aceite (app de teste com os dados de §5.26 — hoje 15/11/2026):
- KPI `net-worth-kpi` mostra 'R$ 46.700,00'; Ultra mostra a variação '-R$ 2.500,00' e um `DeltaBadge`; Simples mostra a linha 'Contas … · Ativos … · A receber … · Dívidas …' e não mostra 'Evolução' nem 'Composição'.
- Ultra: `NetWorthChart` com 12 pontos; tocar '24 meses' em `net-worth-range` → 24 pontos.
- Ultra: `net-worth-breakdown` com 'Dívida de cartão' 'R$ 1.200,00' e 'Faturas em aberto e parcelas futuras já lançadas'.
- Botões 'Novo ativo' e 'Nova dívida' abrem os respectivos diálogos.
- Patrimônio negativo (só uma dívida 'Devo' de 10000) → valor do KPI em `danger`.
- `hideValues` → nenhum valor em claro na página.

### T-163 · Shell e paleta: página Patrimônio e comandos novos · `done` · deps: T-162, T-156, T-157 · parallel: no
files: `lib/app/home_shell.dart`, `lib/app/app_commands.dart`, `test/app/smoke_test.dart`, `test/app/app_commands_test.dart`
contrato: SPEC §7.3 Fase 11 (decisões de navegação: índice 9 `Patrimônio` com `Icons.account_balance_outlined`, `_sidebarOrder`, `_NavTile.number` `int?`, badge Ultra de dívidas `iOwe` vencidas; parágrafo **Paleta**: `onNewAsset`/`onNewDebt` e as 2 entradas depois de 'Nova recorrência'), §7.3 "Páginas (índice)". `_pageFor(9) => const NetWorthPage()`. `GoToPageIntent`/`app_shortcuts.dart` não mudam.
aceite:
- Smoke test (larga e estreita, Simples e Ultra) navega as 10 páginas sem exceção; na larga, 'Patrimônio' fica entre 'Contas' e 'Transações' (`getTopLeft(...).dy`) e as 9 primeiras páginas mantêm o tooltip 'Atalho: {i+1}'; na estreita o item tem tooltip 'Patrimônio'.
- Tecla '9' continua indo para Ajustes (`shell_shortcuts_test.dart` passa sem mudança).
- `buildAppCommands`: 'Ir para Patrimônio' sem `shortcut`; 'Novo ativo' e 'Nova dívida (devo / me devem)' logo depois de 'Nova recorrência'; `fuzzyRank` com 'emprest' acha 'Nova dívida (devo / me devem)'; `onRun` chama o callback certo.
- Ultra com uma dívida `iOwe` vencida → badge '1' no item Patrimônio; Simples sem badge.

### T-164 · Documentação da Fase 11 · `done` · deps: T-150..T-163 · parallel: no
files: `CONTEXT.md`, `ROADMAP.md`, `docs/BACKLOG.md`
contrato: CONTEXT §4 (árvore com `features/net_worth/` e `features/debts/` e seus arquivos; `home_shell.dart` com 10 páginas), §5 (página Patrimônio índice 9 depois de Contas, sem atalho; KPI e Painel Ultra; diferenças Simples/Ultra), §6 (patrimônio líquido, dívida de cartão = saldo devedor já contratado com parcelas futuras, snapshots de ativo, quitação parcial que gera transação, "devo" com vencimento na Previsão e no "posso gastar", "me devem" fora), §7 (boxes `fm_assets` e `fm_debts`; backup e apagar dados cobrem as duas), §8 (testes novos, total), §10 (commit), §11 (status), §12 (limites: editar/excluir a transação de quitação pela tela de Transações não altera a dívida; registrar "me devem" não tira dinheiro de conta — o empréstimo feito precisa ser lançado à parte; quitação de "devo" é despesa e entra no gasto por categoria; dívidas não aparecem em `Ledger.upcoming` (Próximos vencimentos), só nos eventos da previsão; valor de ativo é declarado, sem interpolação; `cardPurchaseDate` aproxima o dia em parcelas com dia clampado; Patrimônio sem atalho numérico). ROADMAP: Fase 11 em "v3". BACKLOG: T-150..T-163 `done`.
aceite: total de testes igual ao de `flutter test`; `bash tool/check.sh` → `CHECK OK`.

## Fase 12 — Relatórios

> Origem: `docs/V3_DIRECTION.md` (Relatórios). Contratos: SPEC §2 (`reports/`), §3.3 (Fase 12), §5.27–5.32, §6.4, §7.3 "Páginas (índice)" e "Relatórios (Fase 12)", §8.
> Sem dependência nova (`csv`, `fl_chart` e `file_selector` já existem). Domínio puro primeiro, com os exemplos do SPEC como teste; controller com cache; views; página; shell por último.
> Decisões fechadas: tela curada com 7 relatórios (`ReportKind`); Simples = Tendência, Top estabelecimentos e Comparativo (só raízes, média 3 meses) com filtro só de período; Ultra = os 7 e todos os filtros. Relatórios usam só transações gravadas (sem recorrências projetadas); estorno, transferência e pagamento de fatura ficam fora (igual a §5.6); despesa de cartão pela data da compra/parcela. Comparativo usa o último mês do período como referência e meses cheios (o mês atual vai "até hoje"). Fixo = `recurringId` ou parcela; variável = o resto. Patrimônio reaproveita `ledger.netWorthHistory` (24 meses; filtros de escopo não se aplicam). Cache no `ReportsController` (fora do `Ledger`; `ledger.dart` não muda), criado pelo shell e vivo enquanto o app roda; matriz mês × categoria compartilhada entre comparativo e pivot. CSV `;` + vírgula decimal + BOM, valores reais mesmo com `hideValues`, ordem padrão do domínio. Página **Relatórios** índice 10, entre Categorias e Ajustes, sem atalho numérico; um comando de paleta por relatório.
> Dependência da Fase 11: T-177 usa `NetWorthPoint` (T-153); T-179 usa `ledger.netWorthHistory` (T-154); T-187 usa `NetWorthChart` (T-158); T-189 toca `home_shell.dart`, `app_commands.dart`, `smoke_test.dart` e `app_commands_test.dart` (também tocados por T-163) → só começa com a Fase 11 fechada (T-164 `done`). Nenhuma tarefa da Fase 12 toca `ledger.dart`, `bootstrap.dart`, `app_scope.dart` ou `backup_service.dart`.
> Ondas (tarefas da mesma onda têm arquivos disjuntos): **A** T-170, T-171 · **B** T-172, T-173, T-174, T-175, T-180 · **C** T-176, T-181, T-182, T-183, T-184, T-185, T-187 (T-187 exige T-153 e T-158) · **D** T-177, T-186 · **E** T-178, T-179 (T-179 exige T-154) · **F** T-188 · **G** (Fase 11 fechada) T-189 · **H** T-190.
> Datas nos testes: `DateTime(2026, 11, 15)` como "hoje" (salvo indicação). Domínio: árvore de categorias de §5.20 (`ali`, `mer`, `res`, `tra`, `sal`). Views: app de teste igual a `test/features/net_worth/net_worth_chart_test.dart` (`bootstrap` em memória, `AppScope`, tema), com os dados montados pelas funções de domínio.

### T-170 · Filtros, período e escopo dos relatórios (domínio) · `done` · deps: — · parallel: yes
files: `lib/features/reports/domain/report_filter.dart` (novo), `test/features/reports/report_filter_test.dart` (novo)
contrato: SPEC §5.27 inteiro (`ReportKind`, `kUltraReports`, `kSimpleReports`, `reportKindLabel`, `reportKindSlug`, `ReportPeriodPreset`, `reportPeriodLabel`, `ReportFlow`, `kReportMaxMonths`, `ReportFilter` com `copyWith`/`periodOnly`/`hasScopeFilters`/`==`/`hashCode`, `ReportRange`, `resolveReportRange`, `monthsOf`, `reportFlowOf`, `matchesReportScope`, `roundDiv`, `reportCategoryLabel`, `ignoredFilters` e a tabela de filtros por relatório). Dart puro; usa `YearMonth`, `CategoryTree`, `hasAnyTag`, `kCategoryPathSeparator`.
aceite:
- Todos os exemplos de §5.27.
- `reportKindLabel` e `reportKindSlug` dos 7; `reportPeriodLabel` dos 6; `kSimpleReports == [trend, topMerchants, categoryComparison]`.
- `ReportFilter()` padrão: `last12`, sets vazios, `expense`, `includePlanned false`, `hasScopeFilters false`; `copyWith` omitido mantém; o filtro guarda `Set.unmodifiable` (mudar o set passado ao construtor depois não altera o filtro).
- `resolveReportRange` em 15/01/2026: `last3` → 2025-11..2026-01; `thisYear` → 2026-01..2026-01.
- `ignoredFilters` para cada `ReportKind` com um filtro que liga tudo (`accountIds`, `categoryIds`, `tagKeys`, `flow income`, `includePlanned`): comparativo, pivot e estabelecimentos → []; tendência, gasto por dia e fixo × variável → ['tipo']; patrimônio → os 5 rótulos na ordem fixa.

### T-171 · `formatCsvMoney` e `csvText` em formatters · `done` · deps: — · parallel: yes
files: `lib/core/utils/formatters.dart`, `test/core/formatters_csv_test.dart` (novo)
contrato: SPEC §3.3 bullet "Fase 12". Mesma lógica de `_csvMoney`/`_csvText` de `backup_service.dart` (que não muda nesta tarefa).
aceite:
- `formatCsvMoney(123456) == '1234,56'`, `(-5000) == '-50,00'`, `(0) == '0,00'`, `(7) == '0,07'`, `(123456789) == '1234567,89'` (sem ponto de milhar).
- `csvText('=SOMA(A1)') == "'=SOMA(A1)"`; `'+1'`, `'-x'` e `'@a'` ganham `'` na frente; `'Mercado'` e `''` inalterados.
- Testes existentes de formatters passam sem mudança.

### T-172 · Matriz mês × categoria e comparativo (domínio) · `done` · deps: T-170 · parallel: yes
files: `lib/features/reports/domain/category_reports.dart` (novo), `test/features/reports/category_reports_test.dart` (novo)
contrato: SPEC §5.28 inteiro (`MonthCategoryTotals`, `monthlyCategoryTotals`, `CategoryComparisonRow`, `CategoryComparison`, `categoryComparison`, regras 1–4). Reusa `deltaRatio` (§5.10), `roundDiv`/`reportFlowOf`/`matchesReportScope`/`reportCategoryLabel` (§5.27), `foldText`.
aceite:
- Exemplo de §5.28 completo (linhas, children na ordem, `total`) e as 4 variações.
- `monthlyCategoryTotals` guarda a categoria própria (`mer`, não `ali`); mês sem lançamentos fica ausente do mapa; despesa fora de `[from, to]` ignorada.
- Categoria apagada (id desconhecido) vira raiz própria e aparece antes de `null`.
- Raiz sem filhas → `children` vazio; raiz com filhas mas só gasto direto → `children` só com a linha `isDirect`.

### T-173 · Tendência, média móvel e fixo × variável (domínio) · `done` · deps: T-170 · parallel: yes
files: `lib/features/reports/domain/monthly_flow.dart` (novo), `test/features/reports/monthly_flow_test.dart` (novo)
contrato: SPEC §5.30 inteiro (`TrendPoint`, `monthlyTrend`, `movingAverage`, `FixedVariableMonth`, `fixedVariableByMonth`). Uma passada sobre as transações por função (mapa mês → índice).
aceite:
- Exemplos de tendência e de fixo × variável de §5.30, com as variações (`includePlanned`, `cardIds {K}`, `flow income` ignorado, mês vazio, parcela com `recurringId`).
- `monthlyTrend` devolve exatamente `months.length` pontos na ordem de `months`, inclusive meses sem lançamento (zeros).
- `movingAverage` com `window` maior que a lista → tudo `null`.
- Fixo × variável com 'Aluguel' na categoria `tra` (demais sem categoria) e `categoryIds {tra}` → out: recorrentes 150000, parcelas 0, variável 0.

### T-174 · Gasto por dia (heatmap, domínio) · `done` · deps: T-170 · parallel: yes
files: `lib/features/reports/domain/spending_heatmap.dart` (novo), `test/features/reports/spending_heatmap_test.dart` (novo)
contrato: SPEC §5.31 parte `spending_heatmap.dart` (`DaySpending`, `SpendingHeatmap` com `levelOf`/`maxDay`/`totalCents`/`activeDays`, `spendingHeatmap`, limiares por quantil).
aceite:
- Exemplo de heatmap de §5.31 inteiro (8 dias, limiares, níveis, `maxDay`, total), dia único e período sem despesas.
- `maxDay` com empate (dois dias de 8000) → o mais antigo.
- Transação com hora (`DateTime(2026, 11, 3, 23, 59)`) cai no dia 03/11; `from`/`to` inclusivos.
- `ReportFilter(flow: income)` → mesmo resultado do padrão (flow ignorado); despesa provisionada só entra com `includePlanned`.

### T-175 · Top estabelecimentos (domínio) · `done` · deps: T-170 · parallel: yes
files: `lib/features/reports/domain/merchant_report.dart` (novo), `test/features/reports/merchant_report_test.dart` (novo)
contrato: SPEC §5.31 parte `merchant_report.dart` (`MerchantTotal`, `merchantKey`, `topMerchants`; memo local de `merchantKey` por texto bruto). Reusa `normalizeDescription`/`foldText` (§3.7) e `ruleSubject` (`features/rules/domain/rule_engine.dart`).
aceite:
- Exemplo de estabelecimentos de §5.31 (3 cenários) com `label`, `purchaseCount`, `averageCents` e `lastDate` exatos.
- `merchantKey`: `importedDescription` vence `description`; descrição só de dígitos sem `importedDescription` → `foldText` da descrição.
- Empate de total → mais compras primeiro; empate de total e compras → `key` asc.
- `categoryId` vem da transação mais recente (empate de data → maior `id`).

### T-176 · Pivot categoria × mês (domínio) · `done` · deps: T-172 · parallel: yes
files: `lib/features/reports/domain/category_pivot.dart` (novo), `test/features/reports/category_pivot_test.dart` (novo)
contrato: SPEC §5.29 inteiro (`PivotRow`, `CategoryPivot` com `maxCellCents`, `categoryPivot`, `PivotSortKey`, `sortPivotRows`). Entrada é a `MonthCategoryTotals` de T-172.
aceite:
- Exemplo de §5.29 completo (cells, totais, `columnTotals`, `grandTotalCents`, `maxCellCents`) e as 4 ordenações.
- `sortPivotRows` devolve lista nova (a original intacta); `null` por último e `isDirect` por último entre as filhas em qualquer ordenação.
- Soma de `columnTotals` == `grandTotalCents` == soma dos `totalCents` das raízes; soma das filhas == total do pai.
- `months` sem dados → `rows` vazio, zeros, `maxCellCents == 0`.

### T-177 · CSV dos relatórios (domínio) · `done` · deps: T-171, T-172, T-173, T-174, T-175, T-176, T-153 · parallel: yes (com T-186)
files: `lib/features/reports/domain/report_csv.dart` (novo), `test/features/reports/report_csv_test.dart` (novo)
contrato: SPEC §5.32 bloco de código e exemplos (`reportCsv` e os 7 `*CsvRows`). Valores com `formatCsvMoney`, texto com `csvText`, `formatDate`, `formatMonth`, `formatPercent` (null → ''), rótulos com `reportCategoryLabel`. `NetWorthPoint` de `features/net_worth/domain/net_worth.dart`.
aceite:
- Todos os exemplos de §5.32 (linhas do comparativo com e sem `includeChildren`, Total, início exato do texto da tendência, Total do pivot, heatmap, estabelecimento sem categoria, proteção de fórmula).
- Cabeçalhos exatos dos 7 relatórios; nº de linhas = cabeçalho + itens (+ 'Total' onde o SPEC define).
- `netWorthCsvRows` com o ponto de out/2026 de §5.26 → `['out/2026', '31/10/2026', '8700,00', '42000,00', '500,00', '800,00', '1200,00', '49200,00']`.
- `fixedVariableCsvRows` do exemplo de §5.30: linha nov `['nov/2026', '1540,00', '200,00', '1740,00', '260,00', '2000,00', '87,0%']`; Total `['Total', '3080,00', '400,00', '3480,00', '720,00', '4200,00', '82,9%']`.

### T-178 · Teste de desempenho dos relatórios · `done` · deps: T-172, T-173, T-174, T-175, T-176, T-177 · parallel: yes (com T-179)
files: `test/features/reports/reports_performance_test.dart` (novo)
contrato: SPEC §5.32 parágrafo **Desempenho** (base sintética `Random(42)`, 20.000 transações × 24 meses, dois filtros, lista de medições). Gerador local no próprio arquivo, sem dado real; transações pelo construtor de `Transaction` e `buildInstallments`.
aceite:
- Base com exatamente 20.000 transações em 2024-12..2026-11 (assert no teste) e as proporções do SPEC (±2 pontos percentuais, assert).
- Cada medição dos dois filtros < 300 ms (`expect(sw.elapsedMilliseconds, lessThan(300), reason: '<relatório>')`).
- Sanidade: com o filtro (a), `categoryPivot(...).grandTotalCents` == soma das despesas não provisionadas da base; `topMerchants` não vazio.
- Se algum relatório passar de 300 ms: otimizar a função de domínio (sem mudar contrato), nunca afrouxar o limite.

### T-179 · `ReportsController` (cache por filtro) · `done` · deps: T-177, T-154 · parallel: yes (com T-178)
files: `lib/features/reports/presentation/reports_controller.dart` (novo), `test/features/reports/reports_controller_test.dart` (novo)
contrato: SPEC §6.4 inteiro (API, regras 1–4). `ChangeNotifier` (`package:flutter/foundation.dart` só aqui; domínio continua puro).
aceite (`bootstrap` em memória com `clock` 15/11/2026; dados de §5.28 e §5.30 gravados):
- `identical(c.trend, c.trend)`, idem `pivot`, `comparison`, `merchants`, `heatmap`, `fixedVariable`.
- `c.filter = ReportFilter(preset: last3)` → notifica 1×, `range == (2026-09, 2026-11)`, `trend.length == 3`; atribuir filtro igual (`==`) → não notifica.
- `transactions.upsert` de despesa nova em nov → controller notifica e `pivot.grandTotalCents` muda; depois de `c.dispose()`, novo `upsert` não lança.
- Simples: `effectiveFilter == filter.periodOnly` (com `cardIds` no filtro, os números ignoram o cartão); `available == kSimpleReports`; `selected = pivot` → `current == trend`.
- Ultra: `averageMonths = 6` → `comparison.averageMonths == 6`; `averageMonths = 5` → ignorado; Simples usa 3.
- `heatmap.to` == 15/11/2026 sem provisionados e 30/11/2026 com `includePlanned`.
- `netWorth` com `last3` → 3 pontos (set, out, nov) iguais aos últimos 3 de `ledger.netWorthHistory`.
- `csvFileName(trend)` com `last3` == 'finme-tendencia-2026-09_2026-11.csv'; `csvFileName(categoryComparison)` == 'finme-comparativo-categorias-2026-11.csv'; `csvFor(pivot)` começa com 'Categoria;set/2026;out/2026;nov/2026;Total'.
- `ignoredFor(netWorth)` com `cardIds` (Ultra) → ['contas e cartões'].

### T-180 · Barra de filtros dos relatórios · `done` · deps: T-170 · parallel: yes
files: `lib/features/reports/presentation/report_filter_bar.dart` (novo), `test/features/reports/report_filter_bar_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`ReportFilterBar`** (`ReportFilterBar`, `showReportMultiSelect`). Cores via `context.colors`; diálogo com guarda contra duplo pop.
aceite (contas 'Conta A' e 'Conta Velha' arquivada; cartão 'Cartão K'; árvore de §5.20; tags ['Viagem', 'casa']):
- Simples: só `report-period` e `report-range` ('dez/2025 – nov/2026' com `last12`); nenhum `report-filter-*`, `report-flow`, `report-planned`.
- Escolher 'Personalizado' → `onChanged` com `preset custom`; com custom aparecem `report-from`/`report-to` e mudar 'De' chama `onChanged` com `customFrom` novo.
- Ultra: `report-filter-accounts` abre o diálogo com 'Conta A', 'Conta Velha (arquivada)' e 'Cartão K'; marcar 'Conta A' e 'Cartão K' + 'Aplicar' → `accountIds {A}`, `cardIds {K}`; com esse filtro o botão mostra 'Contas e cartões: 2'.
- Categorias: opções com 'Alimentação › Mercado' indentada; 'Limpar' → `categoryIds {}`; 'Cancelar' → `onChanged` não é chamado.
- Tags: selecionar 'Viagem' → `tagKeys {VIAGEM}`; sem tags o botão fica desabilitado.
- `report-flow` 'Receitas' → `flow income` com `categoryIds` vazio; `report-planned` → `includePlanned true`; `report-clear` só aparece com `hasScopeFilters` e devolve `periodOnly`.

### T-181 · View do comparativo por categoria · `done` · deps: T-172 · parallel: yes
files: `lib/features/reports/presentation/category_comparison_view.dart` (novo), `test/features/reports/category_comparison_view_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`CategoryComparisonView`** e a regra de ordenação por cabeçalho. `SortableHeaderLabel`, `DeltaBadge`, `MoneyText`, `EmptyState`, `AppMotion`.
aceite (dados de §5.28 via `categoryComparison`):
- Ultra: 'Mês de referência: Novembro 2026 (até hoje)'; linhas Alimentação, Transporte, Sem categoria nessa ordem; 'R$ 516,67' na média de Alimentação; Total 'R$ 830,00'.
- `comparison-expand-ali` → aparecem 'Mercado', 'Restaurante', '(sem subcategoria)'; tocar de novo → somem.
- Clicar no cabeçalho do mês anterior → desc (Alimentação 75000, Transporte 20000) e 'Sem categoria' continua por último; 2º clique → asc.
- `comparison-average` 'Média 6 meses' → chama `onAverageMonthsChanged(6)`.
- Simples: sem `comparison-average`, sem chevron, sem colunas 'Média'/'Vs. média'.
- `hideValues` → nenhum valor em claro; `rows` vazio → 'Sem lançamentos no período com estes filtros.'.

### T-182 · View de tendência · `done` · deps: T-173 · parallel: yes
files: `lib/features/reports/presentation/trend_view.dart` (novo), `test/features/reports/trend_view_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`TrendView`** (`TrendView`, `trendTooltipText`). fl_chart como em `forecast_chart.dart`/`net_worth_chart.dart`; sem gradiente.
aceite (pontos de §5.30):
- `trendTooltipText(nov)` == 'Novembro 2026\nReceitas: R$ 5.200,00\nDespesas: R$ 830,00\nSaldo do mês: R$ 4.370,00'; `hideValues` → 'R$ ••••' nas 3.
- Ultra: 1 `BarChart` e 1 `LineChart`; `trend-average` ligado → o `LineChart` tem 3 linhas; desligado → 1.
- Simples: só o `BarChart`, sem `trend-average`.
- Tabela: 'set/2026' … 'nov/2026' e rodapé 'Total' com 'R$ 15.200,00' em receitas.
- Saldo negativo num mês → `extraLinesData.horizontalLines` não vazio no `LineChart`; todos zero → `EmptyState`.

### T-183 · View fixo × variável · `done` · deps: T-173 · parallel: yes
files: `lib/features/reports/presentation/fixed_variable_view.dart` (novo), `test/features/reports/fixed_variable_view_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`FixedVariableView`** (`FixedVariableView`, `fixedVariableTooltipText`).
aceite (meses de §5.30):
- `fixedVariableTooltipText(nov)` == 'Novembro 2026\nRecorrentes: R$ 1.540,00\nParcelas: R$ 200,00\nVariável: R$ 260,00\nFixo: 87,0% do total'; mês vazio → última linha 'Fixo: –'.
- `BarChart` com `rodStackItems` de 3 itens por barra.
- Tabela com '79,1%' em out, '87,0%' em nov e rodapé 'Total' com '82,9%'.
- Apoio 'Fixo = lançamentos de recorrências e parcelas. Variável = o resto.'; tudo zero → `EmptyState`.

### T-184 · View gasto por dia (heatmap) · `done` · deps: T-174 · parallel: yes
files: `lib/features/reports/presentation/heatmap_view.dart` (novo), `test/features/reports/heatmap_view_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`HeatmapView`** (`HeatmapView`, `heatmapTooltipText`; grade por `offset = from.weekday % 7`, dias via `DateTime(y, m, d + i)`, diferença por `DateTime.utc`).
aceite (heatmap de §5.31, 01/11..30/11/2026):
- 30 células `heatmap-day-*`; `heatmap-day-20261101` (domingo) na linha 0 da coluna 0 e `heatmap-day-20261130` (segunda) na linha 1 da coluna 4 (comparar `getTopLeft`).
- `heatmapTooltipText(03/11, (3000, 2))` == '03/11/2026 · R$ 30,00 · 2 transações'; count 1 → '1 transação'; sem gasto → '03/11/2026 · sem gastos'; `hideValues` → 'R$ ••••'.
- Resumo 'Total R$ 360,00 · 8 dias com gasto · Maior dia: 08/11 (R$ 80,00)'.
- Intervalo de 12 meses (01/12/2025..30/11/2026) renderiza sem exceção e rola na horizontal; sem dias → `EmptyState`.

### T-185 · View top estabelecimentos · `done` · deps: T-175 · parallel: yes
files: `lib/features/reports/presentation/merchants_view.dart` (novo), `test/features/reports/merchants_view_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`MerchantsView`** e a regra de ordenação por cabeçalho.
aceite (lista de §5.31 com período set..nov):
- Ultra: 'LOJA EXEMPLO' primeiro; colunas 'Ticket médio', 'Última compra', 'Categoria'; 'iFood*Restaurante 12/11' com apoio 'IFOOD RESTAURANTE'; rodapé '4 estabelecimentos'.
- Clicar 'Compras' → desc: 'Uber Trip' (3) primeiro.
- Simples: só Estabelecimento, Total e Compras.
- 60 estabelecimentos → 50 linhas e `merchants-show-all` 'Mostrar todos (60)'; tocar → 60 (rolando a lista).
- Vazio → 'Sem compras no período com estes filtros.'.

### T-186 · View pivot categoria × mês · `done` · deps: T-176 · parallel: yes (com T-177)
files: `lib/features/reports/presentation/pivot_view.dart` (novo), `test/features/reports/pivot_view_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`PivotView`** (cabeçalho e rodapé fixos, rolagem horizontal única, `sortPivotRows`, fundo por `maxCellCents`) e a regra de ordenação por cabeçalho.
aceite (pivot de §5.29):
- Linhas `pivot-row-ali`, `pivot-row-tra`, `pivot-row-none` nessa ordem; rodapé 'Total' com 'R$ 2.780,00'; célula zero mostra '–'.
- `pivot-sort-0` (ago, coluna nova → desc) → mesma ordem; `pivot-sort-total` 1× (coluna já ativa → inverte) → Transporte antes de Alimentação; `pivot-sort-label` → Alimentação, Transporte, Sem categoria.
- `pivot-expand-ali` → linhas 'Mercado', 'Restaurante', '(sem subcategoria)' abaixo de Alimentação.
- Janela de 800 px com 24 meses → existe rolagem horizontal e o cabeçalho continua visível depois de arrastar a lista na vertical (`find.text('Categoria')` na mesma posição).
- Vazio → `EmptyState`.

### T-187 · View evolução do patrimônio · `done` · deps: T-153, T-158 · parallel: yes
files: `lib/features/reports/presentation/net_worth_report_view.dart` (novo), `test/features/reports/net_worth_report_view_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)", bloco **`NetWorthReportView`**; reusa `NetWorthChart` (Fase 11) sem alterá-lo.
aceite (3 pontos de §5.26):
- Um `NetWorthChart` com os 3 pontos; tabela com 'set/2026', 'out/2026', 'nov/2026'; 'R$ 46.700,00' no líquido de nov; variação de nov '-R$ 2.500,00'; set '–'.
- Texto de apoio 'Histórico disponível: últimos 24 meses. …' presente.
- Lista vazia → 'Sem histórico de patrimônio no período.'; `hideValues` → nenhum valor em claro.

### T-188 · Página Relatórios · `done` · deps: T-179, T-180, T-181, T-182, T-183, T-184, T-185, T-186, T-187 · parallel: no
files: `lib/features/reports/presentation/reports_page.dart` (novo), `test/features/reports/reports_page_test.dart` (novo)
contrato: SPEC §7.3 "Relatórios (Fase 12)": tabela Simples/Ultra, `reportKindIcon`, bloco **`ReportsPage`** (cabeçalho, filtros fixos, lista lateral, `report-ignored`, `AnimatedSwitcher`, export com `SaveReportCsv` injetável) e o mapeamento kind → view com os dados do controller (§6.4). Filtros: `onChanged: (f) => controller.filter = f`; contas/cartões de `services`, tags de `ledger.allTags`.
aceite (app de teste, `ReportsController` criado no teste; dados de §5.28):
- Ultra: 7 itens `report-tab-*` na ordem de `kUltraReports`; tocar `report-tab-pivot` mostra `PivotView`; `report-tab-netWorth` mostra `NetWorthReportView`.
- Simples: 3 itens (Tendência, Top estabelecimentos, Comparativo por categoria) e a barra só com período; com `selected = pivot` a página abre em Tendência.
- Ultra com `flow income` no relatório Tendência → `report-ignored` 'Filtros ignorados neste relatório: tipo'; sem filtros ignorados → ausente.
- Mudar `report-period` para '3 meses' → `TrendView` com 3 meses (tabela 'set/2026'..'nov/2026').
- `report-export` com `saveCsv` falso → recebe `controller.csvFileName(current)` e um texto que começa com '﻿' + o cabeçalho do relatório; SnackBar 'CSV exportado.'; `saveCsv` que lança → 'Não foi possível exportar o CSV.'; devolve `false` → sem SnackBar.
- Sem transações → cada um dos 7 relatórios (Ultra) mostra seu `EmptyState` sem exceção.

### T-189 · Shell e paleta: página Relatórios e comandos por relatório · `done` · deps: T-188, T-164 (Fase 11 fechada) · parallel: no
files: `lib/app/home_shell.dart`, `lib/app/app_commands.dart`, `test/app/smoke_test.dart`, `test/app/app_commands_test.dart`
contrato: SPEC §7.3 "Páginas (índice)" (10 Relatórios) e "Relatórios (Fase 12)" (navegação: `Icons.insights_outlined`, `_sidebarOrder = [0, 1, 2, 3, 9, 4, 5, 6, 7, 10, 8]`, `number: null`, sem badge; parágrafo **Paleta**: `onOpenReport`, entradas por relatório no grupo 'Relatórios'), §6.4 (shell cria o `ReportsController` uma vez, preguiçoso, e o descarta no `dispose`). `_pageFor(10) => ReportsPage(controller: _reports)`. `GoToPageIntent`/`app_shortcuts.dart` não mudam.
aceite:
- Smoke test (larga e estreita, Simples e Ultra) navega as 11 páginas sem exceção; na larga, 'Relatórios' fica entre 'Categorias' e 'Ajustes' (`getTopLeft(...).dy`); as 9 primeiras páginas mantêm 'Atalho: {i+1}'; tecla '9' continua indo para Ajustes.
- Filtro escolhido na página Relatórios ('3 meses') continua aplicado depois de ir para o Painel e voltar.
- `buildAppCommands`: 'Ir para Relatórios' sem `shortcut`; Ultra com 7 entradas 'Relatório: …' no grupo 'Relatórios' logo depois de 'Nova dívida (devo / me devem)'; Simples com 3; `fuzzyRank` com 'heatmap' acha 'Relatório: Gasto por dia' e com 'onde gasto' acha 'Relatório: Top estabelecimentos'; `onRun` chama `onOpenReport` com o `ReportKind` certo.
- Pela paleta, 'Relatório: Categoria × mês' abre a página Relatórios com o pivot selecionado.

### T-190 · Documentação da Fase 12 e fechamento da v3 · `done` · deps: T-170..T-189 · parallel: no
files: `CONTEXT.md`, `ROADMAP.md`, `docs/BACKLOG.md`
contrato: CONTEXT revisado para o estado final da v3 (cabeçalho com a data; título e §1 como "FinMe v3", sem "rewrite em andamento"), §4 (árvore com `features/reports/` e seus arquivos; `home_shell.dart` com 11 páginas), §5 (página Relatórios índice 10 entre Categorias e Ajustes, sem atalho; os 7 relatórios e a tabela Simples/Ultra; paleta com comandos por relatório), §6 (regras dos relatórios: só transações gravadas; estorno, transferência e pagamento de fatura fora; comparativo com mês de referência = fim do período; fixo = recorrência ou parcela; patrimônio com 24 meses), §7 (sem box nova; CSV de relatórios `;` + vírgula + BOM, valores reais mesmo com valores ocultos), §8 (testes novos, teste de desempenho, total), §10 (commits das Fases 7–12), §11 (status: v3 concluída, Fases 7–12), §12 (limites: filtro de relatório não persiste entre execuções; comparativo do mês atual é parcial ("até hoje") contra o mês anterior cheio; estornos não abatem gasto nos relatórios, igual ao Painel; categoria apagada aparece como 'Categoria removida'; relatórios não incluem recorrências projetadas; ordenação por clique não muda o CSV; heatmap começa a semana no domingo; `backup_service.dart` mantém cópias privadas de `formatCsvMoney`/`csvText`). ROADMAP: Fases 11 e 12 em "v3", v3 marcada como concluída, próximos passos pós-v3. BACKLOG: T-170..T-189 `done`.
aceite: total de testes igual ao de `flutter test`; `bash tool/check.sh` → `CHECK OK`.
