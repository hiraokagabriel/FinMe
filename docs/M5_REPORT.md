# M5 — Refinamento UX/UI

> Marco focado em polimento visual, consistência de componentes e micro-interações.

---

## Status geral

| # | Feature | Status | Commit |
|---|---------|--------|--------|
| M5-A1 | Consistência visual global — `AppEmptyState` em todas as páginas | ✅ Concluído | [32b338d](https://github.com/hiraokagabriel/FinMe/commit/32b338d) |
| M5-A2 | Dashboard — KPI delta absoluto vs mês anterior; link "Ver todas →" | ✅ Concluído | [2bcb07a](https://github.com/hiraokagabriel/FinMe/commit/2bcb07a) |
| M5-A3 | Transações — busca no AppBar, badge de filtros ativos | ✅ Concluído | este commit |
| M5-A4 | Formulários — validação inline, confirmação de exclusão | 🔲 Pendente | — |
| M5-A5 | Navegação — fade 200ms, highlight sidebar | 🔲 Pendente | — |
| M5-A6 | Polimento desktop — scrollbar oculta, tooltips, formatters numéricos | 🔲 Pendente | — |

---

## Detalhes por item

### M5-A1 — AppEmptyState
- `BudgetPage`: removida classe `_EmptyState` privada com `OutlinedButton.icon` → `AppEmptyState`
- `CategoriesPage`: removido bloco `Center > Column` inline → `AppEmptyState` com `actionLabel: 'Nova categoria'`
- Demais páginas (`TransactionsPage`, `CardsPage`, `AccountsPage`, `GoalsPage`) já conformes

### M5-A2 — KPI Delta
- `_SummaryCardData` ganhou `prevValue` (nullable) e `invertDelta` (Despesas: queda = verde)
- Helper `_totalsForMonth(year, month)` extraído; `_previousMonthTotals` calcula mês anterior corretamente via `DateTime(year, month - 1)`
- Delta exibido como `+ R$ 120` / `- R$ 45` em 10px abaixo do valor principal
- Card **"A vencer"** tem `prevValue: null` propositalmente — sem delta exibido

> **📌 Nota futura — Card "A vencer" (M5-A2):**
> O card "A vencer" no Dashboard não exibe delta vs mês anterior pois o valor representa
> obrigações futuras pendentes (não um acumulado do período), tornando a comparação sem
> sentido semântico. Em iterações futuras, considerar:
> - Exibir contagem de itens a vencer (`3 lançamentos`)
> - Ao tocar no card, navegar direto para a seção "A vencer" em `TransactionsPage`
> - Destacar visualmente quando houver itens vencidos (badge vermelho)

### M5-A3 — Busca + Badge de filtros
- Campo de busca collapsível no AppBar (ícone search → TextField inline)
- Filtra por `description` case-insensitive em tempo real
- Badge numérico no ícone de filtro indica quantos filtros não-padrão estão ativos
  (período ≠ `thisMonth` conta como 1; categoria selecionada conta como 1)
- Busca ativa conta como filtro adicional no badge

---

## Observações de arquitetura

- Todos os filtros de `TransactionsPage` persistidos via `PreferencesService` (período + categoria)
- Busca textual é estado local (`_searchQuery`) — não persistida intencionalmente
- Delta de KPI usa apenas transações não-provisionadas, consistente com o cálculo do mês corrente
