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

### T-045 · Teste em dispositivo Android real · `todo` · **manual — usuário** (agentes NÃO executam) · deps: T-040..T-044
files: — (nenhum código; registrar resultado em `CONTEXT.md` §12)
passos: `flutter build apk` (ou `flutter run -d <id>`) em aparelho físico; rodar onboarding com dados de exemplo; navegar pelas 8 páginas nos modos Simples e Ultra; criar compra parcelada, pagar fatura, mudar ciclo de um cartão; exportar e importar backup (seletor de arquivo do Android); girar a tela e testar o drawer.
aceite: sem exceção nem overflow visível; backup exportado reimporta no mesmo aparelho; dados persistem após fechar e reabrir o app. Usuário marca `done` e remove o item de CONTEXT.md §12.
