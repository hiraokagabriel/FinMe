# M4 Scope — FinMe

> **Criado em:** 2026-04-09  
> **Objetivo:** Inteligência financeira passiva — detectar padrões recorrentes, identificar gastos desnecessários e dar ao usuário insights acionáveis sem exigir configuração manual.

---

## Visão Geral

O M4 não introduz novos modelos Hive nem rotas novas. Toda a lógica roda sobre os dados já existentes (`transactions`, `categories`, `budgets`). O trabalho é de **análise e apresentação** — novos serviços de domínio + widgets de insight nas telas existentes.

```
Dados existentes → AnalysisService → InsightWidgets (Dashboard + Reports)
```

---

## Features

### M4-A — Detecção de Assinaturas Recorrentes

**Descrição:** Identificar automaticamente transações que se repetem com frequência mensal/anual e valor similar, classificá-las como "assinaturas" e exibir um painel dedicado com custo total mensal e anual projetado.

**Lógica de detecção (`SubscriptionDetector`):**
1. Agrupar transações por `description` normalizada (lowercase, trim, remover sufixos numéricos)
2. Para cada grupo: verificar se há ≥ 2 ocorrências com intervalo entre 25–35 dias (mensal) ou 350–380 dias (anual)
3. Variação de valor aceita: ≤ 10% em relação à média do grupo
4. Transações com `recurrenceRule != none` são candidatas diretas — não precisam passar pelo detector
5. Resultado: lista de `SubscriptionSummary` com `description`, `categoryId`, `avgAmount`, `frequency`, `lastDate`, `occurrences`

**Arquivos novos:**
- `lib/core/analysis/subscription_detector.dart` — função pura; recebe `List<TransactionEntity>` e retorna `List<SubscriptionSummary>`
- `lib/core/analysis/subscription_summary.dart` — value object imutável

**Arquivos modificados:**
- `lib/features/reports/presentation/reports_page.dart` — nova aba/seção "Assinaturas" com lista de `SubscriptionSummary` e total mensal/anual
- `lib/features/dashboard/presentation/dashboard_page.dart` — card de resumo "Assinaturas ativas" (Modo Ultra apenas): total mensal + count

**Critérios de aceite:**
- [ ] `SubscriptionDetector.detect()` é uma função pura sem side-effects; testável isoladamente
- [ ] Transações com `recurrenceRule.monthly` ou `recurrenceRule.yearly` sempre aparecem como assinatura
- [ ] Transações sem padrão detectado não aparecem na lista
- [ ] Variação de valor > 10% entre ocorrências exclui o grupo
- [ ] `ReportsPage` exibe seção "Assinaturas" com: nome, categoria, valor médio, frequência, total anual projetado
- [ ] Card no Dashboard (Modo Ultra) mostra: N assinaturas ativas, custo mensal total
- [ ] Lista vazia exibe empty state adequado (não erro)
- [ ] Performance: detector roda em isolate ou de forma síncrona tolerável (< 50ms para até 500 transações)

---

### M4-B — Relatório de Gastos Desnecessários

**Descrição:** Analisar os gastos do mês corrente e dos últimos 3 meses para identificar categorias onde o usuário gastou significativamente acima da própria média histórica, e exibir um relatório com os "alertas de desvio".

**Lógica de análise (`SpendingAnalyzer`):**
1. Para cada categoria com transações nos últimos 4 meses (3 histórico + mês atual):
   - Calcular média dos 3 meses históricos (`historicalAvg`)
   - Calcular gasto do mês atual (`currentSpend`)
   - Desvio: `(currentSpend - historicalAvg) / historicalAvg * 100`
2. Classificar como "alerta" se desvio > 30% E `currentSpend > R$ 20` (evitar ruído em valores baixos)
3. Classificar como "crítico" se desvio > 80%
4. Resultado: lista de `SpendingAlert` ordenada por desvio absoluto decrescente

**Arquivos novos:**
- `lib/core/analysis/spending_analyzer.dart` — função pura; recebe `List<TransactionEntity>` + `List<CategoryEntity>` + `DateTime currentMonth` e retorna `List<SpendingAlert>`
- `lib/core/analysis/spending_alert.dart` — value object: `categoryId`, `categoryName`, `historicalAvg`, `currentSpend`, `deviationPct`, `severity` (warning/critical)

**Arquivos modificados:**
- `lib/features/reports/presentation/reports_page.dart` — nova seção "Alertas de gasto" com cards por categoria: desvio em %, valor histórico vs atual, badge de severidade
- `lib/features/dashboard/presentation/dashboard_page.dart` — banner discreto (Modo Ultra + Modo Simples) quando há ≥ 1 alerta crítico no mês corrente

**Critérios de aceite:**
- [ ] `SpendingAnalyzer.analyze()` é função pura; sem side-effects
- [ ] Categorias com menos de 2 meses históricos são ignoradas (dados insuficientes)
- [ ] Gastos abaixo de R$ 20 no mês atual não geram alerta, mesmo com desvio alto
- [ ] Desvio negativo (gastou menos que a média) não gera alerta
- [ ] `ReportsPage` exibe cards de alerta com: nome da categoria, valor médio histórico, valor atual, % de desvio, badge warning/crítico
- [ ] Dashboard mostra banner apenas quando `severity == critical` e Modo Ultra ou Simples ativos
- [ ] Lista vazia exibe mensagem positiva: "Seus gastos estão dentro do padrão este mês"
- [ ] Badge de severidade usa `AppColors.warning` (warning) e `AppColors.danger` (critical) — sem hex direto

---

### M4-C — Seção "Insights" Consolidada na ReportsPage

**Descrição:** Unificar M4-A e M4-B em uma aba/seção dedicada na `ReportsPage` chamada "Insights", mantendo as abas existentes intactas.

**Estrutura de abas após M4-C:**
```
ReportsPage
├── Resumo      (existente — gráficos por período)
├── Categorias  (existente — breakdown por categoria)
└── Insights    (novo — assinaturas + alertas de gasto)
```

**Arquivos modificados:**
- `lib/features/reports/presentation/reports_page.dart` — adicionar `TabBar` com 3 abas se ainda não houver; aba "Insights" renderiza `_SubscriptionsSection` + `_SpendingAlertsSection`

**Critérios de aceite:**
- [ ] Abas existentes (Resumo, Categorias) não regridem
- [ ] Aba "Insights" carrega dados de forma lazy (só quando a aba é selecionada)
- [ ] Em Modo Simples, aba "Insights" é exibida normalmente (insights são valiosos em ambos os modos)
- [ ] Transição entre abas usa `AnimatedSwitcher` ou `TabBarView` sem jank

---

## Arquitetura do M4

```
lib/
└── core/
    └── analysis/              ← novo diretório
        ├── subscription_detector.dart
        ├── subscription_summary.dart
        ├── spending_analyzer.dart
        └── spending_alert.dart
```

**Princípios:**
- Toda lógica de análise em `core/analysis/` — funções puras, sem acesso a Hive
- Nenhum modelo Hive novo — M4 é read-only sobre dados existentes
- Nenhuma rota nova — insights vivem dentro de telas existentes
- Nenhum typeId novo — nada é persistido pelo M4

---

## Ordem de Execução

```
M4-A (SubscriptionDetector + value objects)
  → M4-B (SpendingAnalyzer + value objects)
    → M4-C (Integração na ReportsPage + Dashboard)
```

M4-A e M4-B são independentes entre si e podem ser implementados em paralelo. M4-C depende de ambos.

---

## Checklist Geral

| # | Feature | Arquivos novos | Arquivos modificados | Status |
|---|---------|---------------|---------------------|--------|
| M4-A | Detecção de assinaturas | `subscription_detector.dart`, `subscription_summary.dart` | `reports_page.dart`, `dashboard_page.dart` | 🔲 Pendente |
| M4-B | Alertas de gastos | `spending_analyzer.dart`, `spending_alert.dart` | `reports_page.dart`, `dashboard_page.dart` | 🔲 Pendente |
| M4-C | Seção Insights na ReportsPage | — | `reports_page.dart` | 🔲 Pendente |

---

## Dependências e Riscos

| Risco | Mitigação |
|---|---|
| `ReportsPage` pode não ter `TabBar` ainda | Verificar antes de M4-C; adicionar se necessário sem quebrar layout existente |
| Detector lento com muitas transações | Limitar janela histórica a 12 meses; rodar síncronamente primeiro, mover para isolate se necessário |
| Descrições de transações inconsistentes | Normalização agressiva no detector (lowercase + trim + remoção de números/pontuação) |
| Categorias sem nome (id órfão) | `SpendingAlert.categoryName` usa `categoryId` como fallback — nunca lança exceção |
