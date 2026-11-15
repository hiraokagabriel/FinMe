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

### T-010 · Bootstrap, Ledger, Shell, Onboarding · `todo` · deps: T-003, T-004, T-009
files: `lib/main.dart`, `lib/app/app.dart`, `lib/app/bootstrap.dart`, `lib/app/app_scope.dart`, `lib/app/ledger.dart`, `lib/app/seed.dart`, `lib/app/home_shell.dart`, `lib/features/onboarding/presentation/onboarding_page.dart`, + placeholders `lib/features/{dashboard,forecast,cards,accounts,transactions,recurring,categories,settings}/presentation/<x>_page.dart` (classes `DashboardPage`, `ForecastPage`, `CardsPage`, `AccountsPage`, `TransactionsPage`, `RecurringPage`, `CategoriesPage`, `SettingsPage`, cada um `StatelessWidget` com `Center(Text(...))`), `test/app/ledger_test.dart`
contrato: SPEC §6, §7.3, §7.4
aceite: `bootstrap({RecordStore Function(String box)? storeFactory, DateTime Function()? clock})` permite memória em teste; seed de categorias padrão (12 despesa, 4 receita, sem nomes de empresas reais); seed demo cria ≥ 2 bancos fictícios, 4 cartões (3 crédito, 1 débito), 3 contas, ~40 transações dos últimos 3 meses + parcelas futuras, 4 recorrentes; Ledger memoiza (teste: `forecast` idêntico entre chamadas sem mudança, recalcula após upsert).

### T-011 · Widgets compartilhados · `todo` · deps: T-010
files: `lib/core/widgets/*.dart` (um arquivo por widget do SPEC §7.2 ou agrupados em ≤ 4 arquivos), `lib/core/widgets/widgets.dart` (barrel)
contrato: SPEC §7.2

## Fase 3 — Telas (todas parallel: yes, deps: T-011)

### T-012 · Painel · `todo` · files: `lib/features/dashboard/presentation/*`
### T-013 · Previsão · `todo` · files: `lib/features/forecast/presentation/*`
### T-014 · Cartões e faturas · `todo` · files: `lib/features/cards/presentation/*` (lista por banco, form cartão, detalhe com faturas, pagar fatura)
### T-015 · Contas e transferência · `todo` · files: `lib/features/accounts/presentation/*`
### T-016 · Transações · `todo` · files: `lib/features/transactions/presentation/*` (lista/tabela, filtros, form com parcelas/provisionado/boleto, confirmar provisionado, excluir grupo). Expõe `Future<void> showTransactionForm(BuildContext context, {Transaction? initial})` usado pelo shell.
### T-017 · Recorrentes · `todo` · files: `lib/features/recurring/presentation/*`
### T-018 · Categorias e orçamento · `todo` · files: `lib/features/categories/presentation/*`
### T-019 · Ajustes, backup e CSV · `todo` · files: `lib/features/settings/presentation/*`, `lib/core/services/backup_service.dart`, `test/core/backup_service_test.dart`
contrato comum: SPEC §6.3, §7.3 (tabela Simples/Ultra), `CLAUDE.md` padrões visuais. Ler dados só via `AppScope.of(context)` + `ListenableBuilder(listenable: ledger)`.

## Fase 4 — Integração

### T-020 · Smoke test e polimento · `todo` · deps: T-012..T-019
files: `test/app/smoke_test.dart`, ajustes mecânicos
aceite: app sobe com seed demo em memória, navega 8 páginas nos modos Simples e Ultra, abre form de transação; `CHECK OK`.

### T-021 · Documentação · `todo` · deps: T-020
files: `CONTEXT.md`, `CLAUDE.md` (estrutura), `README.md`, `ROADMAP.md`
