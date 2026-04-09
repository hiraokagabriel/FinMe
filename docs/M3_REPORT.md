# M3 Report — FinMe

> **Atualizado em:** 2026-04-09  
> **Objetivo:** Rastrear o progresso do Marco 3 (M3) item a item. Use este arquivo para solicitar commits conforme cada feature for implementada.

---

## ✅ Concluídos

| # | Feature | Commit |
|---|---------|--------|
| M3-1 | Dashboard/Home com gráfico de linha mensal | #32 |
| M3-2 | Tela de Metas (v1 + v2 unificada) | #33, #44 |
| M3-3 | Relatórios Exportáveis (filtro + CSV) | #34 |
| M3-4 | Tema Escuro com toggle | #36 |
| M3-5 | Recorrência Automática de Transações | #39 |
| M3-6 | Ícones Personalizados por Categoria | #40 |
| M3-A | Múltiplas Contas/Carteiras | #48 |
| M3-B | Transferência entre Contas | #49 |
| M3-C | Splash Screen / Onboarding | #56 |

---

## 🔲 Pendentes

### M3-D — Persistência Definitiva de Preferências Avançadas

**Descrição:** Criar um `PreferencesService` centralizado com box Hive dedicado (`preferences`) para persistir configurações de visualização e do usuário que atualmente se perdem entre sessões ou estão dispersas em boxes genéricas.

**Escopo dividido em duas camadas:**

**Camada 1 — Preferências de configuração do usuário** (persistidas em `preferences`):
- `currency`: código ISO da moeda (ex: `BRL`, `USD`). Default: `BRL`.
- `dateFormat`: formato de exibição de datas (ex: `dd/MM/yyyy`, `MM/dd/yyyy`). Default: `dd/MM/yyyy`.
- `language`: código do idioma (ex: `pt`, `en`). Reservado para M4/M5 — salvar mas não aplicar ainda.

**Camada 2 — Preferências de UI/filtros** (persistidas em `preferences`):
- `transactionsFilterPeriod`: período ativo na `TransactionsPage` (ex: `thisMonth`, `last30days`).
- `transactionsFilterType`: tipo de transação ativo (ex: `all`, `expense`, `income`).
- `transactionsSortOrder`: ordenação preferida (ex: `dateDesc`, `dateAsc`, `valueDesc`).
- `reportsGroupBy`: agrupamento ativo na `ReportsPage` (ex: `byMonth`, `byCategory`).
- `reportsPeriod`: período ativo nos relatórios.

**Arquivos alvo:**
- `lib/core/services/preferences_service.dart` — singleton com Hive box `preferences`; getters/setters tipados para cada chave
- `lib/features/transactions/presentation/transactions_page.dart` — ler filtros e ordenação ao inicializar; persistir ao alterar
- `lib/features/reports/presentation/reports_page.dart` — ler período e agrupamento ao inicializar; persistir ao alterar
- `lib/features/settings/presentation/settings_page.dart` — expor campos de moeda e formato de data vinculados ao `PreferencesService`
- `lib/core/services/hive_init.dart` — abrir box `preferences` no boot

**Critérios de aceite:**
- [ ] Box `preferences` aberta no boot via `HiveInit`, sem adapter customizado (usa tipos primitivos)
- [ ] `PreferencesService.instance` expõe getters/setters para todas as chaves acima
- [ ] Filtros de período, tipo e ordenação da `TransactionsPage` sobrevivem a restart do app
- [ ] Agrupamento e período da `ReportsPage` sobrevivem a restart do app
- [ ] Moeda e formato de data exibidos na `SettingsPage` com persistência imediata ao alterar
- [ ] Sem regressão nas preferências já existentes: tema (`ThemeController`) e modo simples/ultra continuam funcionando normalmente
- [ ] Valores ausentes na box retornam defaults definidos no `PreferencesService` (não lançam exceção)

---

### M3-E — Orçamento Mensal por Categoria

**Descrição:** Permitir ao usuário definir um teto de gasto mensal por categoria, com acompanhamento visual do consumo e alerta quando o limite estiver próximo ou ultrapassado.

**Arquivos alvo:**
- `lib/features/budget/domain/budget_entity.dart` — entidade pura: `id`, `categoryId`, `limitAmount`, `month` (DateTime truncado ao mês)
- `lib/features/budget/data/budget_model.dart` — `@HiveType(typeId: 6)`, adapter escrito manualmente seguindo o padrão de `transaction_model.dart`
- `lib/features/budget/data/budget_repository.dart` — interface abstrata: `getAll`, `getByMonth`, `save`, `delete`
- `lib/features/budget/data/hive_budget_repository.dart` — implementação concreta usando box `budgets`
- `lib/features/budget/presentation/budget_page.dart` — tela principal com lista de orçamentos do mês corrente
- `lib/features/budget/presentation/budget_form_page.dart` (ou modal) — formulário de criação/edição de orçamento
- `lib/app/router.dart` — rota `/budget`
- `lib/core/services/hive_init.dart` — registrar adapter e abrir box `budgets`
- `lib/features/transactions/presentation/transaction_form_page.dart` — exibir alerta inline ao selecionar uma categoria com orçamento próximo do limite

**Critérios de aceite:**
- [ ] `BudgetModel` usa `typeId: 6`; adapter registrado com guard `Hive.isAdapterRegistered(6)` antes de registrar
- [ ] CRUD completo de orçamentos: criar, editar e excluir por categoria + mês
- [ ] Não é possível criar dois orçamentos para a mesma categoria no mesmo mês (validação no repositório)
- [ ] `BudgetPage` exibe lista do mês corrente com barra de progresso colorida:
  - Verde: consumido < 75% do limite
  - Amarelo: consumido entre 75% e 99%
  - Vermelho: consumido ≥ 100%
- [ ] Categoria sem transações no mês exibe barra em 0% sem erro
- [ ] Mês exibido na `BudgetPage` pode ser navegado (mês anterior / próximo)
- [ ] Alerta inline no formulário de nova transação: ao selecionar categoria, se houver orçamento ativo e o consumo atual ≥ 75%, exibir aviso discreto (não bloqueante)
- [ ] Acesso via `SettingsPage` ou item de menu lateral (a definir no momento da implementação)
- [ ] TypeId 6 registrado antes dos demais no `HiveInit` (nunca reutilizar; typeId 1 continua reservado por precaução)

---

## 📌 Ordem de Execução Sugerida

```
M3-D (Preferências)  →  M3-E (Orçamento)
```

M3-D é mais simples e não cria novos modelos Hive. M3-E depende de `PreferencesService` para persistir o mês selecionado na `BudgetPage`.

---

*Após cada commit, marcar o item como ✅ acima e registrar o # do commit.*
