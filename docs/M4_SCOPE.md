# FinMe — Marco M4: Relatório Final

> Atualizado em: 09/04/2026

## Status Geral

**M4 100% concluído.** Todas as features planejadas foram implementadas e verificadas no repositório.

## Features

| # | Feature | Status | Arquivo principal |
|---|---|---|---|
| M4-A | Detecção de assinaturas recorrentes | ✅ Concluído | `lib/core/analysis/subscription_detector.dart` |
| M4-B | Alertas de gastos anormais (spike mensal, dominância de categoria) | ✅ Concluído | `lib/core/analysis/spending_analyzer.dart` |
| M4-C | Relatórios por categoria com barra de progresso | ✅ Concluído | `lib/features/reports/presentation/reports_page.dart` (aba Categorias) |
| M4-D | Exportação CSV com seletor de arquivo nativo | ✅ Concluído | `lib/features/reports/presentation/reports_page.dart` (`_exportCsv`) |

## Detalhes de implementação

### M4-A — Detecção de assinaturas
- Agrupa transações por descrição normalizada
- Detecta padrão mensal (intervalo 25–35 dias) e anual (intervalo 335–395 dias)
- Exibe na aba **Insights** de Relatórios com custo mensal e anual consolidados

### M4-B — Alertas de gastos
- `SpendingAlertType`: `categoryDominant`, `monthlySpike`, `categorySpike`
- Severidade 1 (info) / 2 (warning) / 3 (danger)
- Badge numérico no tab Insights (laranja ou vermelho conforme severidade máxima)

### M4-C — Relatórios por categoria
- Filtros por período: Este mês, Últimos 30/90 dias, Este ano, Personalizado
- Filtro persistido via `PreferencesService.reportsPeriod`
- Barra de progresso colorida com cor da categoria

### M4-D — Exportação CSV
- Colunas: Data, Descrição, Tipo, Categoria, Cartão/Banco, Valor, Provisionado
- Usa `file_selector` para diálogo nativo de salvamento (Windows + Android)
- Limite de 50 transações exibidas na UI; CSV exporta todos

---

## Próximo Marco

### M5 — Refinamento & Distribuição

| # | Feature | Status |
|---|---|---|
| M5-A | Refinamento UX/UI geral | 🔲 Pendente |
| M5-B | Empacotamento `.exe` Windows (MSIX/Inno Setup) | 🔲 Pendente |
| M5-C | APK Android (build de release assinado) | 🔲 Pendente |
