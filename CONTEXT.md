# CONTEXT.md — FinMe v2: estado atual

> Estado em 2026-11-15. Fonte da verdade de domínio: `docs/SPEC.md`. Tarefas e status: `docs/BACKLOG.md`.
> Este arquivo descreve o que existe no código hoje. Atualize-o ao concluir uma fase.

## 1. O que é o FinMe v2

App local (sem backend, sem integração bancária) de **previsibilidade financeira** para quem tem muitos cartões de crédito, contas e faturas.
Pergunta central: *"quanto vai sair, de onde e quando — e meu saldo aguenta?"*

- Faturas certas por cartão (fechamento, vencimento, parcelas, assinaturas).
- Previsão de caixa consolidada e por conta, com alerta de saldo negativo e cobertura de faturas.
- Provisionamento de boletos e despesas planejadas.
- Categorias e orçamento mensal.
- Dois modos sobre o mesmo domínio: **Simples** (enxuto) e **Ultra** (denso). Alternância em Ajustes e no rodapé da sidebar.

Plataformas: Windows (desktop) e Android. Esta é a v2, um rewrite na branch `rewrite/v2`; a v1 foi apagada (ver ROADMAP).

## 2. Stack

- Flutter 3.41 / Dart 3.11 (`environment: sdk: ^3.11.4`).
- Persistência: Hive com mapas (`Box<Map>`). Sem adapters e sem typeIds: cada entidade tem `toMap()`/`fromMap()`.
- Pacotes: `hive`, `hive_flutter`, `path_provider`, `fl_chart` (gráfico de previsão), `csv` (exportação CSV), `file_selector` (salvar/abrir arquivo de backup e CSV), `cupertino_icons`.
- Estado: `ChangeNotifier` + `ListenableBuilder`. Sem pacote de estado.
- Nenhuma outra dependência é permitida.

## 3. Como rodar

- SDK Flutter: `E:\Projetos\FinMe\flutter\bin` (fora do PATH). No Git Bash: `export PATH=/e/Projetos/FinMe/flutter/bin:$PATH`.
- Dependências: `flutter pub get`.
- Rodar: `flutter run -d windows` (ou `flutter run -d <id>` para Android).
- Build: `flutter build windows`, `flutter build apk`.
- Testes: `flutter test`.
- **Portão obrigatório:** `bash tool/check.sh` (format + analyze + test). Termina com `CHECK OK`. O script acha o SDK sozinho.

## 4. Arquitetura

Regras: `domain/`, `core/models/` e `core/utils/` são Dart puro (sem `package:flutter`). Dinheiro é `int` em centavos. Formatação só em `core/utils/formatters.dart`. Cores só via `context.colors`.

```
lib/
  main.dart                       runApp(bootstrap)
  app/
    app.dart                      FinMeApp (MaterialApp, tema, home)
    bootstrap.dart                abre boxes fm_*, cria repositórios, seed, materializa recorrências
    app_scope.dart                AppServices + AppScope (InheritedWidget, estável)
    ledger.dart                   visões derivadas memoizadas por versão (faturas, saldos, previsão, Fase 5)
    home_shell.dart               sidebar (>= 900px) / drawer; índice de 8 páginas; modo Simples/Ultra
    seed.dart                     categorias padrão + dados de exemplo fictícios (Banco Alfa, Banco Beta)
  core/
    models/                       year_month.dart (YearMonth), app_settings.dart (AppSettings, AppMode)
    services/                     record_store.dart (RecordStore, Hive/memória), collection_repository.dart (CollectionRepository<T>),
                                  settings_controller.dart, backup_service.dart (JSON + CSV)
    theme/                        app_colors.dart (ThemeExtension), app_theme.dart, app_spacing.dart, app_palettes.dart
    utils/                        formatters.dart (dinheiro/data), date_utils.dart, id.dart
    widgets/                      MoneyText, SectionCard, EmptyState, LimitBar, StatusBadge, DateField, MoneyField, KpiTile...
  features/
    accounts/domain/              account.dart (Account), balances.dart (saldos por conta)
    accounts/presentation/        accounts_page.dart, account_form.dart, transfer_dialog.dart
    cards/domain/                 payment_card.dart (PaymentCard, CardCycle), invoice_cycle.dart (ciclo), invoice.dart (faturas),
                                  card_insights.dart (melhor cartão, parcelas comprometidas, cartão sem conta)
    cards/presentation/           cards_page.dart, card_tile.dart, card_detail_page.dart, card_form.dart, pay_invoice_dialog.dart, best_card_panel.dart
    transactions/domain/          transaction.dart (Transaction), installments.dart (parcelas)
    transactions/presentation/    transactions_page.dart, transaction_row.dart, transaction_form.dart, transaction_filters.dart
    recurring/domain/             recurring_rule.dart (RecurringRule), recurrence.dart (ocorrências, status)
    recurring/presentation/       recurring_page.dart, recurring_form.dart
    categories/domain/            transaction_category.dart, category_spending.dart (gasto e orçamento por categoria)
    categories/presentation/      categories_page.dart, category_form.dart
    forecast/domain/              forecast.dart (motor de previsão), invoice_timeline.dart (vencimentos e cobertura)
    forecast/presentation/        forecast_page.dart, forecast_chart.dart (fl_chart), forecast_events.dart,
                                  forecast_installments.dart, forecast_invoice_timeline.dart, forecast_summary.dart
    dashboard/presentation/       dashboard_page.dart, dashboard_summary.dart, dashboard_sections.dart
    settings/presentation/        settings_page.dart (modo, tema, ocultar valores, horizonte, backup, CSV, apagar dados)
    onboarding/presentation/      onboarding_page.dart (escolha de modo + dados de exemplo)
test/                             espelha lib/ (app, core, features) — ver seção 8
```

## 5. Features implementadas

Páginas (índice do `HomeShell`): 0 Painel, 1 Previsão, 2 Cartões, 3 Contas, 4 Transações, 5 Recorrentes, 6 Categorias, 7 Ajustes. Botão global "Nova transação".

| Tela | Simples | Ultra |
|---|---|---|
| **Painel** | KPIs (saldo atual, a pagar em 30 dias, fim do mês previsto), próximas faturas, próximos vencimentos, banner de saldo negativo e de cobertura de faturas | + cards de faturas com limite, lista de categorias com participação no gasto, alerta de cobertura por conta, badge de contagem na sidebar (faturas vencidas e provisionados atrasados) |
| **Previsão** | cards por mês (entradas, saídas, faturas, saldo final) | + gráfico de linha do saldo diário, tabela de eventos, linha do tempo de vencimentos (60 dias), compromisso de parcelas M+1..M+12 |
| **Cartões** | lista por banco, fatura atual, painel "melhor cartão para comprar hoje" (1 linha) | + tabela do melhor cartão, limite usado/total, badge de assinaturas ativas, badge "Sem conta de pagamento" (em ambos os modos) |
| **Detalhe do cartão** | — | faturas passadas e futuras, itens por fatura, pagamento de fatura |
| **Contas** | saldo atual | + saldo previsto ao fim do mês, transferência entre contas |
| **Transações** | colunas data, descrição, valor; filtro por mês | colunas extras (banco/cartão, categoria), filtros por conta/cartão/categoria/tipo, busca, toggle de provisionados, rodapé com totais |
| **Recorrentes** | lista e total mensal | + separação de assinaturas, custo anual |
| **Categorias** | lista de categorias e gasto do mês | + orçamentos e barra de consumo |
| **Ajustes** | modo, tema, ocultar valores | + horizonte de previsão, backup JSON (exportar/importar), CSV mensal de transações, apagar dados |

Transações: parcelas (compra em N vezes), provisionado (ainda não pago, itálico + `PlannedMarker`), boleto, confirmar provisionado, duplicar, excluir grupo de parcelas.
Onboarding: escolha de modo e opção "Criar dados de exemplo" (fictícios).

## 6. Regras financeiras-chave

Detalhes completos em `docs/SPEC.md` §5. Resumo:

- **Ciclo de fatura** (§5.1): compra no dia do fechamento ou depois vai para a próxima fatura. Mudança de dias de fechamento/vencimento com transações exige vigência (`withCycleChange`, §4.2).
- **Faturas** (§5.2): status open/closed/paid/overdue; pagamento parcial gera saldo restante; estorno abate.
- **Parcelas** (§5.3): centavos distribuídos sem perda (100,00 em 3x = 33,34 + 33,33 + 33,33).
- **Recorrência** (§5.4): mensal, semanal e anual com fim de mês clampado (31 → 28/29 ou 30); ocorrência já materializada não duplica.
- **Saldos** (§5.5): provisionado não afeta saldo; transferência move entre contas; débito afeta a conta; crédito só afeta a conta ao pagar a fatura.
- **Categorias** (§5.6): gasto inclui cartão, exclui transferência e receita.
- **Previsão** (§5.7): eventos por conta e consolidados; saldo negativo marcado; fatura paga não gera evento.
- **Insights de cartão** (§5.8): melhor cartão para comprar hoje considera dias até o vencimento e limite livre (cartão sem limite fica de fora); cartão sem conta de pagamento é sinalizado.
- **Cobertura de faturas** (§5.9): fatura nos próximos dias cuja conta de pagamento fica negativa (`needsAttention`).

## 7. Persistência

- Boxes Hive: `fm_accounts`, `fm_cards`, `fm_categories`, `fm_transactions`, `fm_recurring`, `fm_settings`.
- Dados da v1 são **ignorados** (outros nomes de box, outro formato). Nenhuma migração.
- Todos os dados ficam em memória no boot; escrita no Hive é assíncrona. Derivados caros são memoizados no `Ledger`.
- Registro corrompido é pulado na carga (não derruba o boot).
- Backup JSON: exportar e importar (`replaceAll` grava novos antes de apagar antigos). CSV: transações do mês.
- Excluir conta ou cartão com transações: só arquivar.

## 8. Testes

- `test/app/`: ledger, insights do ledger, smoke test (app sobe com seed em memória e navega).
- `test/core/`: `year_month`, utils, theme, widgets, `collection_repository`, `backup_service`.
- `test/features/`: entidades, faturas, ciclo de cartão, parcelas e recorrência, saldos e categorias, previsão, linha do tempo de vencimentos, insights de cartão, e widget tests das telas (cartões, contas, transações, recorrentes, categorias, previsão, painel, ajustes). Onboarding ainda sem teste dedicado.
- Domínio e `core/utils|models|services` têm testes unitários. Widget tests usam `MemoryRecordStore`.

## 9. Workflow de agentes

- `.claude/agents/`:
  - `finme-planner` (opus, effort medium): transforma pedido em SPEC e tarefas no BACKLOG. Não escreve código.
  - `finme-coder` (haiku, effort high): implementa **uma** tarefa `T-XXX` do BACKLOG.
  - `finme-verifier` (haiku, effort high): roda format/analyze/test e corrige erros mecânicos.
  - `finme-reviewer` (opus, effort medium, somente leitura): revisa corretude financeira, aderência ao SPEC e desempenho.
- `.claude/skills/finme-auto/SKILL.md` (`/finme-auto [T-XXX|feature]`): orquestra planner → coders → verifier → reviewer → commit. Thread principal em opus.

## 10. Histórico do rewrite (v2)

- `83f9729` fundação: agentes, workflow finme-auto, SPEC e BACKLOG (T-001)
- `3001a6a` força LF em scripts shell
- `0ba379c` utilitários, tema, persistência e entidades de domínio (T-002..T-005)
- `c000583` faturas, parcelas, recorrência, saldos e gastos por categoria (T-006..T-008)
- `e30c1a1` motor de previsão de caixa (T-009)
- `46ce375` correções da revisão do domínio: parcelas por fatura, import atômico, boot resiliente (T-009b)
- `52d0cd3` bootstrap, Ledger memoizado, seed demo, shell e onboarding (T-010)
- `ea4daa7` widgets compartilhados e status de recorrência materializada (T-010b, T-011)
- `478314b` telas Painel, Previsão, Cartões, Contas, Transações, Recorrentes, Categorias e Ajustes (T-012..T-019)
- `6cb402c` polimento pós-revisão e domínio da Fase 5 (T-020a/b, T-030..T-032)
- `06b1531` previsibilidade: cobertura de faturas, vencimentos 60 dias, parcelas comprometidas, melhor cartão, ciclo com vigência (T-033..T-038)

## 11. Status

- Fases 0–5 concluídas (`docs/BACKLOG.md`). T-021 (documentação) em andamento.
- Próximos passos sugeridos: ver ROADMAP.md.

## 12. Pendências conhecidas

- Sem teste em dispositivo Android real.
- `copyWith` não limpa campos nulos; os formulários recriam a entidade pelo construtor.
- Fusão de faturas no mês de troca de ciclo é simplificação (SPEC §5.1).
- Import de backup não é atômico entre coleções (cada coleção grava sozinha).
- Linha do tempo de vencimentos promete 60 dias, mas com `forecastMonths = 3` e hoje no fim de janeiro o horizonte cobre 59 dias (último dia fica fora).
