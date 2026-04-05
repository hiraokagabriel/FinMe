# CONTEXT.md — FinMe: Estado Atual do Projeto

> **Para uso da IA:** Este arquivo é a fonte da verdade sobre o que está implementado, como o projeto está estruturado e o que falta fazer. Consulte-o antes de qualquer commit.  
> **Última atualização:** 2026-04-05

---

## 1. O que é o FinMe

Aplicativo Flutter de **gestão financeira pessoal** para Android (com estrutura também para iOS, Windows, Linux, macOS e Web). O foco principal é controle de transações, cartões de crédito, categorias, recorrências e metas financeiras.

- **Stack:** Flutter (Dart) + Hive (banco local) + fl_chart (gráficos) + csv (exportação)
- **Persistência:** 100% local via Hive (sem backend/API)
- **Versão atual:** 1.0.0+1

---

## 2. Estrutura de Pastas

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart                    # Rotas: /, /transactions, /cards, /settings, /goals, /reports, /accounts, /transfer
├── core/
│   ├── models/
│   │   ├── app_mode.dart
│   │   ├── date_range.dart
│   │   └── money.dart
│   ├── services/
│   │   ├── hive_init.dart             # Abre box 'accounts' + registra AccountModelAdapter
│   │   ├── app_mode_controller.dart
│   │   ├── theme_controller.dart
│   │   ├── recurrence_service.dart
│   │   └── repository_locator.dart    # Expõe RepositoryLocator.instance.accounts
│   ├── theme/
│   │   └── app_theme.dart
│   └── utils/
└── features/
    ├── transactions/
    │   ├── domain/
    │   │   ├── transaction_entity.dart # accountId + toAccountId + notes (M3-B)
    │   │   ├── transaction_type.dart   # income | expense | transfer (M3-B)
    │   │   ├── payment_method.dart
    │   │   └── recurrence_rule.dart
    │   ├── data/
    │   │   ├── transaction_model.dart  # índices 15 (toAccountId) e 16 (notes) adicionados
    │   │   ├── transactions_repository.dart
    │   │   └── hive_transactions_repository.dart
    │   └── presentation/
    │       ├── transactions_page.dart
    │       └── new_transaction_page.dart
    ├── categories/
    │   ├── domain/
    │   ├── data/
    │   └── presentation/
    ├── cards/
    │   ├── domain/
    │   ├── data/
    │   └── presentation/
    ├── accounts/                       # ✅ M3-A
    │   ├── domain/
    │   │   └── account_entity.dart
    │   ├── data/
    │   │   ├── account_model.dart
    │   │   ├── accounts_repository.dart
    │   │   └── hive_accounts_repository.dart
    │   └── presentation/
    │       └── accounts_page.dart
    ├── transfer/                       # ✅ M3-B
    │   └── presentation/
    │       └── transfer_page.dart      # Seleciona origem/destino, valor, data, descrição
    ├── dashboard/
    │   └── presentation/
    │       └── dashboard_page.dart
    ├── goals/
    │   ├── domain/
    │   ├── data/
    │   └── presentation/
    │       └── goals_page.dart
    ├── reports/
    │   └── presentation/
    │       └── reports_page.dart
    └── settings/
        └── presentation/
            └── settings_page.dart
```

---

## 3. Features Implementadas (✅ Concluído)

### 3.1 Transações
- CRUD completo de transações (criar, editar, excluir)
- Tipos: receita (`income`), despesa (`expense`) e transferência (`transfer`) ✅ M3-B
- Métodos de pagamento: dinheiro, débito, crédito, pix, boleto, outros
- Filtros: por período, por tipo, por categoria, por método de pagamento
- Busca textual por título
- Agrupamento por data na listagem
- Suporte a notas/observações por transação
- Campo `accountId` + `toAccountId` na `TransactionEntity` (M3-A / M3-B)

### 3.2 Recorrência Automática ✅ (M3)
- `RecurrenceRule` com frequências: `daily`, `weekly`, `monthly`, `yearly`
- `RecurrenceService.generatePending()` roda no boot
- Gera automaticamente transações recorrentes pendentes

### 3.3 Categorias com Ícones Personalizados ✅ (M3)
- CRUD completo de categorias
- Picker de ícone (emoji/codepoint)
- Ícone exibido na listagem de transações

### 3.4 Cartões de Crédito
- CRUD de cartões com limite, dia de fechamento e dia de vencimento
- Fatura automática do mês vigente
- Gráficos de uso do limite

### 3.5 Dashboard Aprimorado ✅ (M3)
- KPIs do mês + gráfico de linha mensal + últimas transações

### 3.6 Tela de Metas ✅ (M3)
- CRUD de metas (Meta de Economia + Teto de Gastos)
- Barra de progresso com alertas verde/amarelo/vermelho

### 3.7 Relatórios Exportáveis ✅ (M3)
- Filtros por período + exportação CSV

### 3.8 Tema Claro / Escuro ✅ (M3)
- `ThemeController` singleton com toggle persistido via Hive

### 3.9 Múltiplas Contas/Carteiras ✅ (M3-A)
- `AccountEntity` com tipos: Conta Corrente, Poupança, Dinheiro, Investimento, Outro
- `AccountModel` (typeId 3) + `AccountModelAdapter` manual
- `HiveAccountsRepository` com CRUD e setDefault
- `AccountsPage`: listagem com saldo calculado pelas transações, CRUD via bottom sheet, cor personalizada
- Seed automático com 3 contas padrão no primeiro boot
- Rota `/accounts` registrada no router
- `RepositoryLocator.instance.accounts` disponível globalmente
- `TransactionEntity.accountId` preparado para vincular transações a contas

### 3.10 Transferência entre Contas ✅ (M3-B)
- `TransactionType.transfer` adicionado ao enum
- `TransactionEntity.toAccountId` + `notes` adicionados
- `TransactionModel` atualizado: índices 15 (`toAccountId`) e 16 (`notes`) retrocompatíveis
- `TransferPage`: seleção de conta origem/destino, valor, data, descrição opcional
- Lança débito na origem e crédito no destino como par de transações vinculadas
- Empty state se o usuário tem menos de 2 contas (com botão para criar)
- Rota `/transfer` registrada no router

### 3.11 Modo Privacidade
- Valores monetários ocultados quando ativo

### 3.12 Modo Simples / Ultra
- UI diferenciada por modo
- Persistência via Hive

### 3.13 Persistência
- Hive com adapters manuais (sem build_runner)
- TypeIds: `0` TransactionModel, `1` CategoryModel, `2` CardModel, `3` AccountModel, `5` GoalModel
- Boxes: `transactions`, `categories`, `cards`, `settings`, `goals`, `accounts`

---

## 4. Features Pendentes — M3 (restantes)

| # | Feature | Arquivo(s) alvo | Status |
|---|---------|-----------------|--------|
| M3-C | **Splash Screen / Onboarding** | `lib/features/onboarding/` + ajuste `main.dart` | 🔲 Pendente |
| M3-D | **Persistência definitiva de preferências avançadas** | `lib/core/services/` + Hive box `preferences` | 🔲 Pendente |
| M3-E | **Orçamento Mensal por Categoria** | `lib/features/budget/` | 🔲 Pendente |

---

## 5. Dependências (pubspec.yaml)

| Pacote | Versão | Uso |
|--------|--------|-----|
| `hive` | ^2.2.3 | Banco de dados local |
| `hive_flutter` | ^1.1.0 | Integração Hive com Flutter |
| `path_provider` | ^2.1.5 | Diretório de dados do app |
| `fl_chart` | ^0.70.2 | Gráficos |
| `csv` | ^6.0.0 | Exportação de relatórios |
| `file_selector` | ^1.0.3 | Seletor de arquivos |
| `cupertino_icons` | ^1.0.8 | Ícones iOS |

---

## 6. Convenções do Projeto

### Arquitetura
- **Clean Architecture** por feature: `domain/` → `data/` → `presentation/`
- Estado: `StatefulWidget` + `setState` + `ValueNotifier`
- Repositórios injetados via `RepositoryLocator`
- Adapters Hive **sem** build_runner — escritos manualmente

### Nomenclatura
- `*_entity.dart` — entidades puras do domínio
- `*_model.dart` — modelos Hive com `@HiveType`/`@HiveField`
- `*_repository.dart` — interface abstrata
- `hive_*_repository.dart` — implementação concreta
- `*_page.dart` — telas completas
- `*_controller.dart` — singletons com estado global

### Hive TypeIds
| TypeId | Classe |
|--------|--------|
| 0 | TransactionModel |
| 1 | CategoryModel |
| 2 | CardModel |
| 3 | AccountModel ✅ |
| 4 | *(reservado para BudgetModel)* |
| 5 | GoalModel ✅ |

### Rotas
| Rota | Tela |
|------|------|
| `/` | DashboardPage |
| `/transactions` | TransactionsPage |
| `/cards` | CardsPage |
| `/settings` | SettingsPage |
| `/goals` | GoalsPage |
| `/reports` | ReportsPage |
| `/accounts` | AccountsPage ✅ |
| `/transfer` | TransferPage ✅ |

---

## 7. Pontos de Atenção

1. **Sem build_runner:** Adapters Hive escritos manualmente. Seguir padrão de `transaction_model.dart`.
2. **Sem navigator 2.0:** Manter `Navigator.pushNamed` simples.
3. **fl_chart já incluso:** Usar `fl_chart` para gráficos.
4. **csv já incluso:** Usar `csv` para exportação.
5. **ThemeController:** Usar `ThemeController.instance` para troca de tema.
6. **AppText sem cores fixas:** `AppText` herda cor do tema (commit #37).
7. **Chave Hive por id (string):** Todos registros usam `entity.id` como chave (commit #26).
8. **AppRadius.chip:** Usar `AppRadius.chip` para chips/badges (commit #36).
9. **TransactionType.transfer:** Ao exibir transações na UI, tratar `transfer` separado de `income`/`expense` — não somar ao saldo duas vezes. O par `_out`/`_in` representa os dois lados da transferência.
10. **TransactionModel índices 15/16:** Campos `toAccountId` e `notes` são opcionais/nullable — registros antigos sem esses campos continuam lidos corretamente.

---

## 8. Histórico Completo de Commits

> Numerados do mais antigo (#1) ao mais recente. Use este registro para rastrear features e bugs.

---

### #1 — Initial commit
**SHA:** `832733cb` | **Tipo:** chore  
Criação do repositório no GitHub.

### #2 — Initial commit: projeto Flutter FinMe
**SHA:** `e35a66f2` | **Tipo:** chore  
Scaffold do projeto Flutter.

### #3 — Initialize README
**SHA:** `b20cc5b6` | **Tipo:** docs  
README inicial com visão geral.

### #4 — Documentação inicial (CLAUDE.md e ROADMAP.md)
**SHA:** `35f50bc0` | **Tipo:** docs  
Primeiros arquivos de documentação.

### #5 — Add ROADMAP.md and CLAUDE.md
**SHA:** `76ab4bf7` | **Tipo:** docs  
Segunda versão dos arquivos de documentação.

### #6 — Refactor lib structure
**SHA:** `900cfd8d` | **Tipo:** refactor  
Estrutura de pastas refatorada, skeleton inicial.

### #7 — Implement M2 domain models
**SHA:** `cd3d2430` | **Tipo:** feat (M2)  
Domain models, repositórios em memória, TransactionsPage.

### #8 — Fix imports and currency string
**SHA:** `d247b42b` | **Tipo:** fix  
Correção de imports quebrados.

### #9 — Make DateRange non-const
**SHA:** `5937e7bc` | **Tipo:** fix  
Erro de compilação no DateRange.

### #10 — Refine M2: cards listing page
**SHA:** `2e87d9c5` | **Tipo:** feat (M2)  
CardsPage criada, totais em TransactionsPage.

### #11 — Fix missing CardType import
**SHA:** `e1ca6a5e` | **Tipo:** fix  
Import ausente em CardsRepository.

### #12 — Add docs/TROUBLESHOOTING.md
**SHA:** `9ffd3d5a` | **Tipo:** docs  
Guia de problemas comuns.

### #13 — Implement M3: app mode, settings page
**SHA:** `a5b78026` | **Tipo:** feat (M3)  
AppModeController, SettingsPage, UI adaptativa.

### #14 — Fix encoding issues in AppModeController
**SHA:** `efd42bfa` | **Tipo:** fix  
Null bytes corrigidos.

### #15 — Add Hive-based local persistence
**SHA:** `063b30d7` | **Tipo:** feat  
HiveInit, RepositoryLocator, modelos Hive.

### #16 — Add CRUD and NewTransactionPage
**SHA:** `064508b8` | **Tipo:** feat  
Formulário completo de transação.

### #17 — Allow editing and deleting transactions
**SHA:** `9bf4e3ef` | **Tipo:** feat  
Dismissible + edição via toque.

### #18 — Add CRUD for cards
**SHA:** `12a3e728` | **Tipo:** feat  
CRUD de cartões, vínculo com transações.

### #19 — Add card limit visualization
**SHA:** `aee4a7e0` | **Tipo:** feat  
ProgressIndicator + donut chart + fl_chart.

### #20 — Fix import paths in settings_page
**SHA:** `3d38aa44` | **Tipo:** fix  
Imports apontando para core/.

### #21 — Fix corrupted null-byte sequences in dashboard
**SHA:** `ac124ab2` | **Tipo:** fix  
Null bytes no dashboard_page.

### #22 — feat(M2+M3): CRUD de categorias, filtros
**SHA:** `2689f785` | **Tipo:** feat  
CategoriesPage, filtros em transações.

### #23 — fix: barra debug e layout do cartão
**SHA:** `00571cef` | **Tipo:** fix  
Debug bar removida.

### #24 — fix: seed categories com put
**SHA:** `45e352a4` | **Tipo:** fix  
Chave única no seed de categorias.

### #25 — fix: remove const das seed lists
**SHA:** `4c2c39a6` | **Tipo:** fix  
Const em modelos Hive removido.

### #26 — fix: usar chave id (não índice) no delete
**SHA:** `bb2c214e` | **Tipo:** fix  
Migração de chave numérica → string.

### #27 — feat(M3): modo simples enxuto
**SHA:** `cb760a78` | **Tipo:** feat (M3)  
Modo Simples real, provisionamento, preferências.

### #28 — docs: padrão visual no CLAUDE.md
**SHA:** `eb79294` | **Tipo:** docs  
Paleta, tipografia, mockups no CLAUDE.md.

### #29 — feat: aplica paleta modo claro nos menus
**SHA:** `ad8da191` | **Tipo:** feat  
Tokens do design system nos menus.

### #30 — feat: aplica paleta em transactions/settings/categories
**SHA:** `0fc41226` | **Tipo:** feat  
Padronização visual completa do modo claro.

### #31 — docs: atualiza roadmap
**SHA:** `913ec04d` | **Tipo:** docs  
ROADMAP.md refletindo estado real do M3.

### #32 — feat(dashboard): gráfico de linha mensal
**SHA:** `c970b00c` | **Tipo:** feat (M3)  
DashboardPage reescrita com KPIs e fl_chart.

### #33 — feat(goals): tela de metas v1
**SHA:** `2f1a1248` | **Tipo:** feat (M3)  
GoalsPage, GoalEntity, GoalModel (typeId 5).

### #34 — feat(reports): relatórios com filtro e CSV
**SHA:** `4896b0f0` | **Tipo:** feat (M3)  
ReportsPage com exportação CSV.

### #35 — fix(goals): crash no dropdown
**SHA:** `0ac24c07` | **Tipo:** fix  
Dropdown de categorias com loading lazy.

### #36 — feat(theme): tema escuro com toggle
**SHA:** `66858493` | **Tipo:** feat (M3)  
ThemeController + toggle em SettingsPage.

### #37 — fix(theme): remove cores fixas dos AppText
**SHA:** `7a624c51` | **Tipo:** fix  
AppText herda cor do tema.

### #38 — fix(persistence): corrige persistência entre sessões
**SHA:** `03b33cba` | **Tipo:** fix  
Modo e tema restaurados corretamente no boot.

### #39 — feat(recurrence): recorrência automática
**SHA:** `de224688` | **Tipo:** feat (M3)  
RecurrenceRule + RecurrenceService.generatePending().

### #40 — feat(categories): ícones personalizados
**SHA:** `2cc5f2ec` | **Tipo:** feat (M3)  
Picker de ícone + CategoryEntity.icon.

### #41 — feat(dashboard): KPI 'A vencer' + últimas transações
**SHA:** `e2b3d3eb` | **Tipo:** feat (M3)  
KPI no Modo Simples + seção recentes.

### #42 — fix: erros de compilação no dashboard_page
**SHA:** `833cf73d` | **Tipo:** fix  
AppText.sm → secondary, nullable, categoryId.

### #43 — fix: AppRadius.sm → AppRadius.chip
**SHA:** `48c2dedc` | **Tipo:** fix  
Badges e chips com token correto.

### #44 — feat(goals): tela unificada metas v2
**SHA:** `15c5c379` | **Tipo:** feat (M3)  
TabBar Meta de Economia + Teto de Gastos.

### #45 — docs: adiciona CONTEXT.md
**SHA:** `f37b5654` | **Tipo:** docs  
CONTEXT.md criado.

### #46 — docs: histórico de commits no CONTEXT.md
**SHA:** `513bcae2` | **Tipo:** docs  
Histórico #1–#46 adicionado.

### #47 — docs: reescreve CONTEXT.md definitivo
**SHA:** *(anterior)* | **Tipo:** docs  
CONTEXT.md reescrito com histórico oficial.

### #48 — feat(accounts): múltiplas contas/carteiras ✅ (M3-A)
**SHA:** *(commit anterior)* | **Tipo:** feat (M3)  
M3-A completo — AccountEntity, AccountModel, HiveAccountsRepository, AccountsPage, seed automático, rota /accounts.

### #49 — feat(transfer): transferência entre contas ✅ (M3-B)
**SHA:** `c871a23a` | **Tipo:** feat (M3)  
**M3-B — Transferência entre Contas.** Feature completa implementada:
- `TransactionType.transfer` adicionado ao enum
- `TransactionEntity.toAccountId` + `notes` adicionados
- `TransactionModel` atualizado: índices 15 (`toAccountId`) e 16 (`notes`) retrocompatíveis
- `TransferPage`: seleção de conta origem/destino, valor, data, descrição opcional
- Lança débito na origem e crédito no destino como par de transações
- Empty state se < 2 contas cadastradas
- Rota `/transfer` registrada no router
- CONTEXT.md atualizado

---

*Este arquivo deve ser atualizado a cada commit. Marque os itens da seção 4 como ✅ conforme forem entregues.*
