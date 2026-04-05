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
├── main.dart                          # Entry point: inicializa Hive, ThemeController, AppModeController, RecurrenceService
├── app/
│   ├── app.dart                       # FinMeApp widget raiz (MaterialApp + tema + rotas)
│   └── router.dart                    # Rotas nomeadas: /, /transactions, /cards, /settings, /goals, /reports
├── core/
│   ├── models/
│   │   ├── app_mode.dart              # Enum: AppMode (normal, privacy)
│   │   ├── date_range.dart            # Modelo de intervalo de datas
│   │   └── money.dart                 # Classe Money com formatação BRL
│   ├── services/
│   │   ├── hive_init.dart             # Inicializa e abre todos os Hive boxes + registra adapters
│   │   ├── app_mode_controller.dart   # Singleton: controla modo privacidade (persiste em Hive)
│   │   ├── theme_controller.dart      # Singleton: controla tema claro/escuro (persiste em Hive)
│   │   ├── recurrence_service.dart    # Gera transações pendentes de recorrência no boot
│   │   └── repository_locator.dart    # Service locator simples para os repositórios
│   ├── theme/
│   │   └── app_theme.dart             # ThemeData completo: light e dark, cores, tipografia
│   └── utils/                         # (pasta reservada, vazia com .gitkeep)
└── features/
    ├── transactions/                   # Feature principal: lançamentos financeiros
    │   ├── domain/
    │   │   ├── transaction_entity.dart # Entidade pura: id, title, amount, date, type, category, paymentMethod, recurrenceRule, notes
    │   │   ├── transaction_type.dart   # Enum: income | expense
    │   │   ├── payment_method.dart     # Enum: cash | debit | credit | pix | boleto | other
    │   │   └── recurrence_rule.dart    # Modelo: frequency (daily/weekly/monthly/yearly) + endDate
    │   ├── data/
    │   │   ├── transaction_model.dart  # HiveObject com TypeAdapters gerados manualmente (typeId 0)
    │   │   ├── transactions_repository.dart       # Interface abstrata do repositório
    │   │   └── hive_transactions_repository.dart  # Implementação concreta com Hive box
    │   └── presentation/
    │       ├── transactions_page.dart  # Lista de transações com filtros, busca, agrupamento por data
    │       └── new_transaction_page.dart # Formulário completo de nova/editar transação
    ├── categories/
    │   ├── domain/                     # CategoryEntity: id, name, icon (String emoji/unicode), color
    │   ├── data/                       # HiveCategoriesRepository + CategoryModel (typeId 1)
    │   └── presentation/               # CategoriesPage: CRUD de categorias com ícone personalizado ✅
    ├── cards/
    │   ├── domain/                     # CardEntity: id, name, limit, closingDay, dueDay, color
    │   ├── data/                       # HiveCardsRepository + CardModel (typeId 2)
    │   └── presentation/               # CardsPage: lista de cartões, fatura atual, lançamentos do cartão
    ├── dashboard/
    │   └── presentation/
    │       └── dashboard_page.dart     # Tela inicial: KPIs do mês + gráfico de linha mensal + últimas transações
    ├── goals/
    │   ├── domain/                     # GoalEntity + GoalType (savingsGoal / spendingCeiling)
    │   ├── data/                       # HiveGoalsRepository + GoalModel (typeId 5)
    │   └── presentation/
    │       └── goals_page.dart         # Tela de metas com CRUD, barra de progresso, badge de alerta ✅
    ├── reports/
    │   └── presentation/
    │       └── reports_page.dart       # Tela de relatórios com filtro por período e exportação CSV ✅
    └── settings/
        └── presentation/
            └── settings_page.dart      # Configurações: tema, modo privacidade, categorias, sobre
```

---

## 3. Features Implementadas (✅ Concluído)

### 3.1 Transações
- CRUD completo de transações (criar, editar, excluir)
- Tipos: receita (`income`) e despesa (`expense`)
- Métodos de pagamento: dinheiro, débito, crédito, pix, boleto, outros
- Filtros: por período, por tipo, por categoria, por método de pagamento
- Busca textual por título
- Agrupamento por data na listagem
- Suporte a notas/observações por transação
- Provisionamento de gastos futuros (parcelas + data de vencimento, Ultra only)
- Seção "A vencer" destacada no topo (Ultra only)

### 3.2 Recorrência Automática ✅ (M3)
- Modelo `RecurrenceRule` com frequências: `daily`, `weekly`, `monthly`, `yearly`
- `RecurrenceService.generatePending()` roda no boot do app
- Gera automaticamente as transações recorrentes pendentes desde a última execução
- Campo `recurrenceParentId` liga cada cópia gerada à transação original

### 3.3 Categorias com Ícones Personalizados ✅ (M3)
- CRUD completo de categorias
- Cada categoria tem: nome, cor e ícone (emoji/codepoint)
- Picker de ícone na tela de criação/edição de categoria
- Categorias exibidas com ícone em toda a listagem de transações

### 3.4 Cartões de Crédito
- CRUD de cartões com limite, dia de fechamento e dia de vencimento
- Cálculo automático de fatura do mês vigente
- Listagem de transações vinculadas ao cartão
- Visualização de uso do limite (LinearProgressIndicator + donut chart por cartão)
- Gráfico pizza de despesas por cartão (Ultra only)

### 3.5 Dashboard Aprimorado ✅ (M3)
- KPIs do mês: saldo, entradas, saídas, "a vencer"
- Gráfico de linha mensal (receitas vs. despesas nos últimos meses)
- Seção de últimas transações

### 3.6 Tela de Metas ✅ (M3)
- CRUD de metas com dois tipos: Meta de Economia e Teto de Gastos
- Barra de progresso com indicadores verde/amarelo/vermelho
- Teto de Gastos calculado automaticamente pelas transações do mês/categoria
- Formulário dinâmico que adapta campos conforme o tipo

### 3.7 Relatórios Exportáveis ✅ (M3)
- Filtros por período
- Exportação CSV
- Estrutura pronta para expansão com gráficos

### 3.8 Tema Claro / Escuro ✅ (M3)
- `ThemeController` singleton persiste preferência no Hive
- `app_theme.dart` define `ThemeData` completo para light e dark
- Toggle disponível em `SettingsPage`
- Paleta modo claro aplicada em todas as telas (transactions, settings, categories, menus)
- `AppText` herda cor do tema (sem cores fixas hardcoded)

### 3.9 Modo Privacidade
- `AppModeController` persiste modo em Hive
- Quando ativo, valores monetários são ocultados na tela

### 3.10 Modo Simples / Ultra
- UI diferenciada por modo: Simples (enxuto, sem gráficos, sem cartão) e Ultra (completo)
- Persistência de modo entre sessões via Hive

### 3.11 Persistência
- Hive com adapters manuais (sem build_runner)
- TypeIds: `0` = TransactionModel, `1` = CategoryModel, `2` = CardModel, `5` = GoalModel
- Boxes: `transactions`, `categories`, `cards`, `settings`, `goals`
- `HiveInit` centraliza abertura de todos os boxes e registro dos adapters
- Migração de registros legados (chave numérica → chave por id) no primeiro boot

---

## 4. Features Pendentes — M3 (restantes)

| # | Feature | Arquivo(s) alvo | Status |
|---|---------|-----------------|--------|
| 3 | **Múltiplas Contas/Carteiras** | Novo feature: `lib/features/accounts/` + integração em transactions | 🔲 Pendente |
| 4 | **Transferência entre Contas** | Depende do item 3; novo tipo de transação `transfer` | 🔲 Pendente |
| 8 | **Splash Screen / Onboarding** | `lib/features/onboarding/` + ajuste no `main.dart` | 🔲 Pendente |
| 9 | **Persistência definitiva de preferências avançadas** | `lib/core/services/` + Hive box `preferences` | 🔲 Pendente |

---

## 5. Dependências (pubspec.yaml)

| Pacote | Versão | Uso |
|--------|--------|-----|
| `hive` | ^2.2.3 | Banco de dados local |
| `hive_flutter` | ^1.1.0 | Integração Hive com Flutter |
| `path_provider` | ^2.1.5 | Diretório de dados do app |
| `fl_chart` | ^0.70.2 | Gráficos (linha, pizza, barra) |
| `csv` | ^6.0.0 | Exportação de relatórios |
| `file_selector` | ^1.0.3 | Seletor de arquivos para importação |
| `cupertino_icons` | ^1.0.8 | Ícones iOS |

---

## 6. Convenções do Projeto

### Arquitetura
- **Clean Architecture** por feature: `domain/` → `data/` → `presentation/`
- Sem GetX, Provider ou Riverpod — estado gerenciado via `StatefulWidget` + `setState` + `ValueNotifier`
- Repositórios injetados via `RepositoryLocator` (service locator simples)
- Adapters Hive **sem** build_runner — escritos manualmente

### Nomenclatura
- `*_entity.dart` — entidades puras do domínio (sem anotações Hive)
- `*_model.dart` — modelos Hive com `@HiveType` e `@HiveField`
- `*_repository.dart` — interface abstrata
- `hive_*_repository.dart` — implementação concreta
- `*_page.dart` — telas completas (rotas)
- `*_controller.dart` — singletons de serviço com estado global

### Hive TypeIds
| TypeId | Classe |
|--------|--------|
| 0 | TransactionModel |
| 1 | CategoryModel |
| 2 | CardModel |
| 3 | *(reservado para AccountModel — M3 item 3)* |
| 4 | *(reservado para BudgetModel — futuro)* |
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

---

## 7. Pontos de Atenção

1. **Sem build_runner:** Os adapters Hive são escritos manualmente. Ao adicionar um novo `HiveObject`, sempre escrever o adapter na mão seguindo o padrão de `transaction_model.dart`.
2. **Sem navigator 2.0:** A navegação usa `Navigator.pushNamed` simples. Manter esse padrão.
3. **fl_chart já incluso:** Para gráficos do dashboard e relatórios, usar `fl_chart` (LineChart, PieChart, BarChart). Não adicionar outra lib de charts.
4. **csv já incluso:** Para exportação, usar o pacote `csv`. Para PDF, verificar se precisará adicionar `pdf` ao pubspec.
5. **ThemeController:** Para qualquer componente que precise trocar tema dinamicamente, usar `ThemeController.instance` e chamar `setState` no widget pai via `ValueNotifier`.
6. **AppText sem cores fixas:** Após o commit #10, os widgets `AppText` herdam cor do tema. Nunca definir cor hardcoded em `AppText`.
7. **Chave Hive por id (string):** Após o commit #20, todos os registros usam `entity.id` como chave no box Hive. Não usar índice numérico.
8. **AppRadius.chip:** Usar `AppRadius.chip` para elementos do tipo chip/badge. `AppRadius.sm` foi removido para esse uso (commit #28).

---

## 8. Histórico Completo de Commits

> Numerados do mais antigo (#1) ao mais recente (#35). Use este registro para rastrear onde features foram introduzidas e onde bugs foram corrigidos.

---

### #1 — Initial commit
**SHA:** `832733cb`  
Criação do repositório no GitHub. Commit inicial gerado automaticamente.

---

### #2 — Initial commit: projeto Flutter FinMe
**SHA:** `e35a66f2`  
Scaffold do projeto Flutter gerado com `flutter create`. Estrutura base do app criada.

---

### #3 — Initialize README with project details and instructions
**SHA:** `b20cc5b6`  
README inicial adicionado com visão geral do projeto, modos de uso (Simples/Ultra) e features planejadas.

---

### #4 — Documentação inicial (CLAUDE.md e ROADMAP.md)
**SHA:** `35f50bc0`  
Primeiros arquivos de documentação criados: `CLAUDE.md` com convenções do projeto e `ROADMAP.md` com os marcos planejados (M1 a M5).

---

### #5 — Add ROADMAP.md and CLAUDE.md with project structure and guidelines
**SHA:** `76ab4bf7`  
Segunda versão dos arquivos de documentação, com estrutura de pastas detalhada e guidelines de desenvolvimento.

---

### #6 — Refactor lib structure and add initial app/dashboard skeleton
**SHA:** `900cfd8d`  
Refatoração da estrutura de pastas `lib/`. Criação do skeleton inicial do app com `app.dart`, `router.dart` e `dashboard_page.dart` placeholder.

---

### #7 — Implement M2 domain models, in-memory repositories, and transactions page with navigation from dashboard
**SHA:** `cd3d2430`  
**Marco M2 inicial.** Criação dos domain models (`TransactionEntity`, `CategoryEntity`, `CardEntity`), repositórios em memória e `TransactionsPage` com navegação a partir do dashboard.

---

### #8 — Fix imports and currency string in TransactionsPage
**SHA:** `d247b42b`  
Correção de imports quebrados e string de moeda mal formatada em `TransactionsPage`.

---

### #9 — Make DateRange constructor non-const to avoid const assertion on method call
**SHA:** `5937e7bc`  
Fix de erro de compilação: `DateRange` não pode ser `const` pois possui método que altera estado.

---

### #10 — Refine M2: add cards listing page and summary totals to transactions page
**SHA:** `2e87d9c5`  
**M2 refinado.** Adicionada `CardsPage` com listagem de cartões. Totais de receitas/despesas exibidos no cabeçalho de `TransactionsPage`.

---

### #11 — Fix missing CardType import in CardsRepository
**SHA:** `e1ca6a5e`  
Correção de import ausente de `CardType` em `CardsRepository`, causando erro de compilação.

---

### #12 — Add docs/TROUBLESHOOTING.md with common Git and Flutter issues and fixes
**SHA:** `9ffd3d5a`  
Documentação de troubleshooting adicionada em `docs/TROUBLESHOOTING.md` com soluções para problemas comuns de Git e Flutter.

---

### #13 — Implement M3: app mode (simple/ultra), settings page, and adaptive UI on dashboard, transactions, and cards
**SHA:** `a5b78026`  
**Marco M3 iniciado.** Implementação do `AppModeController`, `SettingsPage` e UI adaptativa por modo (Simples/Ultra) nas telas de dashboard, transações e cartões.

---

### #14 — Fix encoding issues in AppModeController by rewriting file as clean UTF-8 Dart source
**SHA:** `efd42bfa`  
Correção de sequências unicode corrompidas (null bytes) no `AppModeController` — arquivo reescrito como UTF-8 limpo.

---

### #15 — Add Hive-based local persistence for cards, categories, and transactions, and wire UI to use repository locator backed by Hive instead of in-memory mocks
**SHA:** `063b30d7`  
**Persistência real com Hive.** `HiveInit`, `RepositoryLocator`, `TransactionModel` (typeId 0), `CategoryModel` (typeId 1), `CardModel` (typeId 2). UI conectada aos repositórios reais no lugar dos mocks em memória.

---

### #16 — Add CRUD methods to transactions repositories and implement NewTransactionPage to create transactions in Hive, refreshing list and summary on return
**SHA:** `064508b8`  
`NewTransactionPage` implementada. CRUD completo de transações: criar, salvar em Hive, atualizar lista e totais ao retornar.

---

### #17 — Allow editing and deleting transactions from the UI by enhancing NewTransactionPage to handle edits and wrapping list items in Dismissible with confirmation dialog and edit-on-tap behaviour
**SHA:** `9bf4e3ef`  
Edição e exclusão de transações. Lista usa `Dismissible` com diálogo de confirmação. Toque em item abre edição em `NewTransactionPage`.

---

### #18 — Add CRUD support and UI for cards and link transactions to cards in ultra mode, showing card information in transaction list
**SHA:** `12a3e728`  
CRUD completo de cartões. Transações vinculadas a cartões (Ultra only). Info do cartão exibida na lista de transações.

---

### #19 — Add card limit usage visualization (LinearProgressIndicator + donut chart per card) and expenses-by-card pie chart in ultra mode, plus fl_chart dependency and special character fixes across all UI strings
**SHA:** `aee4a7e0`  
Visualização de uso do limite por cartão (barra de progresso + donut chart). Gráfico pizza de despesas por cartão (Ultra). Dependência `fl_chart` adicionada ao pubspec. Correção de caracteres especiais em toda a UI.

---

### #20 — Fix: correct import paths in settings_page.dart (point to core/ instead of features/settings/)
**SHA:** `3d38aa44`  
Correção de caminhos de import em `settings_page.dart` que apontavam para pasta inexistente.

---

### #21 — Fix: replace corrupted null-byte unicode sequences with plain ASCII in dashboard_page.dart
**SHA:** `ac124ab2`  
Remoção de sequências unicode corrompidas (null bytes) no `dashboard_page.dart`.

---

### #22 — feat(M2+M3): CRUD de categorias, filtros em transações, persistência de modo e UI diferenciada simples/ultra
**SHA:** `2689f785`  
CRUD de categorias implementado. Filtros por tipo, período e categoria em `TransactionsPage`. Persistência do modo Simples/Ultra confirmada. UI diferenciada por modo concluída.

---

### #23 — fix: corrige barra debug e layout quebrado do nome do cartão
**SHA:** `00571cef`  
Remoção da debug bar visível na UI. Correção de layout do nome do cartão que estava quebrado.

---

### #24 — fix: seed categories with put (id as key) and cache futures to prevent DropdownButton duplicate-value crash
**SHA:** `45e352a4`  
Seed de categorias agora usa `put(id, model)` como chave. Futures cacheados para evitar crash de valor duplicado no `DropdownButton`.

---

### #25 — fix: remove const from seed lists (CardModel/CategoryModel have no const ctor) and fix string interpolation escape in new_transaction_page
**SHA:** `4c2c39a6`  
Remoção de `const` de listas de seed (modelos Hive não têm construtor `const`). Correção de escape em interpolação de string.

---

### #26 — fix: use box key (not entity.id) for delete; migrate legacy numeric-keyed records to id-keyed on first open
**SHA:** `bb2c214e`  
Exclusão usa a chave do box Hive (não `entity.id`). Migração automática de registros legados com chave numérica para chave por string id no primeiro boot.

---

### #27 — feat(M3): modo simples enxuto, provisionamento e persistência de preferências
**SHA:** `cb760a78`  
Modo Simples realmente enxuto: sem filtro de categoria, sem gráficos, sem campo cartão, resumo único. Provisionamento de gastos futuros: campos `installmentCount` e `provisionedDueDate` (índices Hive 11 e 12). Seção "A vencer" no topo (Ultra only).

---

### #28 — docs: adiciona padrão visual completo (paletas, tipografia, mockups) ao CLAUDE.md
**SHA:** `eb79294`  
`CLAUDE.md` atualizado com paleta de cores completa (light/dark), tipografia, espaçamentos e mockups de referência visual para manter consistência nos commits futuros.

---

### #29 — feat: aplica paleta modo claro em todos os menus via AppTheme centralizado
**SHA:** `ad8da191`  
Paleta do modo claro aplicada em todos os menus do app via `AppTheme` centralizado. Menus deixam de usar cores hardcoded.

---

### #30 — feat: aplica paleta modo claro em transactions, settings e categories
**SHA:** `0fc41226`  
Paleta do modo claro aplicada especificamente nas telas de transações, configurações e categorias.

---

### #31 — docs: atualiza roadmap com progresso real de M1, M2 e M3
**SHA:** `913ec04d`  
`ROADMAP.md` atualizado refletindo M1 e M2 como concluídos e o progresso real do M3.

---

### #32 — feat(dashboard): substitui placeholder por dashboard aprimorado com gráfico de linha mensal
**SHA:** `c970b00c`  
**M3 — Dashboard.** Tela inicial reescrita com KPIs do mês (saldo, entradas, saídas) e gráfico de linha mensal mostrando evolução de receitas vs. despesas.

---

### #33 — feat(goals): tela de metas com CRUD, barra de progresso e badge de alerta
**SHA:** `2f1a1248`  
**M3 — Metas v1.** `GoalsPage` com CRUD de metas, barra de progresso visual e badges de alerta (verde/amarelo/vermelho).

---

### #34 — feat(reports): tela de relatórios com filtro por período e exportação CSV
**SHA:** `4896b0f0`  
**M3 — Relatórios.** `ReportsPage` com filtro por período e exportação dos dados em CSV usando o pacote `csv`.

---

### #35 — fix(goals): corrige crash no dropdown ao abrir formulário de nova meta
**SHA:** `0ac24c07`  
Correção de crash ao abrir o formulário de nova meta: dropdown de categorias inicializava com valor inválido.

---

### #36 — feat(theme): tema escuro com toggle persistido nas configurações
**SHA:** `66858493`  
**M3 — Tema Escuro.** `ThemeController` com toggle persistido via Hive. Toggle disponível em `SettingsPage`. `ThemeData` completo para dark mode.

---

### #37 — fix(theme): remove cores fixas dos AppText para herdar cor do tema
**SHA:** `7a624c51`  
Widgets `AppText` tinham cores hardcoded que quebravam o dark mode. Removidas para herdar cor do tema automaticamente.

---

### #38 — fix(persistence): corrige persistência do modo e tema entre sessões
**SHA:** `03b33cba`  
Modo Simples/Ultra e tema claro/escuro agora são corretamente restaurados ao reabrir o app.

---

### #39 — feat(recurrence): recorrência automática de transações (diária, semanal, mensal, anual)
**SHA:** `de224688`  
**M3 — Recorrência.** `RecurrenceRule` e `RecurrenceService` implementados. Transações recorrentes geradas automaticamente no boot para as frequências: daily, weekly, monthly, yearly.

---

### #40 — feat(categories): ícones personalizados por categoria
**SHA:** `2cc5f2ec`  
**M3 — Ícones.** Picker de ícone adicionado ao formulário de categorias. Ícone exibido junto ao nome da categoria em toda a listagem de transações.

---

### #41 — feat(dashboard): adiciona KPI 'A vencer' no Modo Simples e seção de últimas transações
**SHA:** `e2b3d3eb`  
Dashboard aprimorado: KPI "A vencer" adicionado também ao Modo Simples. Seção "Últimas transações" incluída na home.

---

### #42 — fix: corrige erros de compilação no dashboard_page (AppText.sm → secondary, description nullable, category → categoryId)
**SHA:** `833cf73d`  
Correção de 3 erros de compilação no dashboard: uso incorreto de `AppText.sm`, campo `description` nullable não tratado e referência a `category` em vez de `categoryId`.

---

### #43 — fix: substituir AppRadius.sm por AppRadius.chip no dashboard_page
**SHA:** `48c2dedc`  
`AppRadius.sm` foi renomeado/removido. Substituído por `AppRadius.chip` no dashboard.

---

### #44 — feat(goals): tela unificada de Metas de Economia + Teto de Gastos
**SHA:** `15c5c379`  
**M3 — Metas v2 (reescrita).** `GoalsPage` reescrita com TabBar separando os dois tipos: Meta de Economia (valor acumulado vs. alvo) e Teto de Gastos (calculado automaticamente pelas transações do mês/categoria). `GoalType` enum adicionado. `GoalEntity` atualizada com `type`, `targetAmount`, `title` e `currentAmount`. Alertas visuais: verde (<80%), amarelo (>=80%), vermelho (estourado).

---

### #45 — docs: adiciona CONTEXT.md com estado atual do projeto para referência de IA
**SHA:** `f37b5654`  
`CONTEXT.md` criado com documentação completa do estado atual do projeto para referência da IA em commits futuros.

---

### #46 — docs: adiciona histórico completo de commits ao CONTEXT.md
**SHA:** *(este commit)*  
Histórico de todos os commits numerados (#1 a #46) adicionado ao `CONTEXT.md` para rastreabilidade total do projeto.

---

*Este arquivo deve ser atualizado a cada commit significativo. Marque os itens da seção 4 como ✅ conforme forem entregues.*
