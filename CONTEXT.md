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
    │       └── dashboard_page.dart     # Tela inicial: KPIs do mês (saldo, entradas, saídas) — SEM gráfico ainda
    ├── goals/
    │   └── presentation/
    │       └── goals_page.dart         # Tela de metas — estrutura criada mas sem lógica implementada
    ├── reports/
    │   └── presentation/
    │       └── reports_page.dart       # Tela de relatórios — estrutura criada mas sem lógica implementada
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

### 3.2 Recorrência Automática ✅ (M3 — entregue)
- Modelo `RecurrenceRule` com frequências: `daily`, `weekly`, `monthly`, `yearly`
- `RecurrenceService.generatePending()` roda no boot do app
- Gera automaticamente as transações recorrentes pendentes desde a última execução
- Campo `recurrenceParentId` liga cada cópia gerada à transação original

### 3.3 Categorias com Ícones Personalizados ✅ (M3 — entregue)
- CRUD completo de categorias
- Cada categoria tem: nome, cor e ícone (emoji/codepoint)
- Picker de ícone na tela de criação/edição de categoria
- Categorias exibidas com ícone em toda a listagem de transações

### 3.4 Cartões de Crédito
- CRUD de cartões com limite, dia de fechamento e dia de vencimento
- Cálculo automático de fatura do mês vigente
- Listagem de transações vinculadas ao cartão

### 3.5 Tema Claro / Escuro (estrutura)
- `ThemeController` singleton persiste preferência no Hive
- `app_theme.dart` define `ThemeData` completo para light e dark
- Toggle disponível em `SettingsPage`
- **Obs:** o dark theme existe no código mas a UI não está 100% polida para dark mode

### 3.6 Modo Privacidade
- `AppModeController` persiste modo em Hive
- Quando ativo, valores monetários são ocultados na tela

### 3.7 Persistência
- Hive com adapters manuais (sem build_runner)
- TypeIds: `0` = TransactionModel, `1` = CategoryModel, `2` = CardModel
- Boxes: `transactions`, `categories`, `cards`, `settings`
- `HiveInit` centraliza abertura de todos os boxes e registro dos adapters

---

## 4. Features Pendentes — M3

| # | Feature | Arquivo(s) alvo | Status |
|---|---------|-----------------|--------|
| 1 | **Dashboard com gráfico de linha mensal** | `lib/features/dashboard/presentation/dashboard_page.dart` | 🔲 Pendente |
| 2 | **Tela de Metas (lógica completa)** | `lib/features/goals/` — precisa de domain/data/presentation completos | 🔲 Pendente |
| 3 | **Múltiplas Contas/Carteiras** | Novo feature: `lib/features/accounts/` + integração em transactions | 🔲 Pendente |
| 4 | **Transferência entre Contas** | Depende do item 3; novo tipo de transação `transfer` | 🔲 Pendente |
| 5 | **Orçamento Mensal por Categoria** | Novo feature: `lib/features/budget/` | 🔲 Pendente |
| 6 | **Relatórios Exportáveis (lógica completa)** | `lib/features/reports/` — precisa de domain/data/presentation + export CSV/PDF | 🔲 Pendente |
| 7 | **Dark Theme polido** | `lib/core/theme/app_theme.dart` + revisão de todos os widgets | 🔲 Pendente |
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
| 4 | *(reservado para BudgetModel — M3 item 5)* |
| 5 | *(reservado para GoalModel — M3 item 2)* |

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

---

## 8. Histórico de Commits Relevantes (M3)

| Data | O que foi feito |
|------|----------------|
| 2026-04-05 | Estrutura inicial do projeto criada (Flutter + Hive + features scaffolding) |
| 2026-04-05 | Implementação de `RecurrenceService` e `RecurrenceRule` — transações recorrentes ✅ |
| 2026-04-05 | Picker de ícones para categorias — ícones personalizados por categoria ✅ |
| 2026-04-05 | `CONTEXT.md` criado para documentação contínua do projeto |

---

*Este arquivo deve ser atualizado a cada commit significativo. Marque os itens da seção 4 como ✅ conforme forem entregues.*
