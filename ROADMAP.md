# Roadmap – FinMe

Este arquivo dá uma visão geral da direção do FinMe e das próximas etapas de desenvolvimento.  
O roadmap é organizado em marcos (M1, M2, …), cada um com um foco específico.

> Este roadmap é um documento vivo e será atualizado conforme novas funcionalidades forem desenvolvidas e prioridades mudarem.

---

## Visão geral

FinMe é um app de finanças para pessoas que lidam com **alto volume de cartões, contas e bancos**, com foco em:

- Provisionamento de gastos futuros.
- Visão consolidada de gastos passados, recentes e próximos.
- Organização de dezenas de cartões (10, 20, 30+), inclusive múltiplos cartões do mesmo banco.
- Dois modos de uso: **Modo Simples** (iniciante) e **Modo Ultra** (usuário avançado).

---

## Estado atual

- Status: **Em desenvolvimento ativo**.
- Plataforma principal atual: **Windows (desktop)**.
- Público alvo inicial: usuário final avançado (quem trabalha com muitos cartões), mas com espaço para iniciantes via Modo Simples.
- Progresso geral atual:
  - **M1: concluído**.
  - **M2: concluído**.
  - **M3: concluído**.
  - **M4: concluído**.
  - **M5-A: concluído**.
  - **M5-B: em planejamento**.

---

## M1 – Infraestrutura básica & setup de desenvolvimento

**Objetivo:** Ter um projeto Flutter estruturado, rodando em desktop, com base para evolução.

**Status:** ✅ **Concluído**

**Itens entregues:**

- Projeto Flutter criado e versionado no GitHub.
- Organização inicial de pastas em `lib/`:
  - `lib/app/`
    - `app.dart` (widget raiz, `MaterialApp`).
    - `router.dart` (definição de rotas/navegação).
  - `lib/core/`
    - `models/` (modelos genéricos, ex.: Money, DateRange).
    - `services` (serviços genéricos, ex.: storage local, controller de modo, inicialização Hive).
    - `utils/` (helpers e funções utilitárias).
    - `theme/` (cores, tipografia, temas).
  - `lib/features/`
    - `cards/` (cartões e bancos – `data/`, `domain/`, `presentation/`).
    - `transactions/` (receitas, despesas, boletos – `data/`, `domain/`, `presentation/`).
    - `categories/` (categorias de despesa/receita – `data/`, `domain/`, `presentation/`).
    - `dashboard/` (tela inicial e visões consolidadas – `presentation/`).
    - `settings/` (configurações do app, incluindo Modo Simples/Ultra – `presentation/`).
- Navegação básica entre dashboard, transações, cartões e configurações.
- Dashboard inicial com placeholder funcional e ações rápidas.

---

## M2 – Núcleo financeiro (MVP funcional)

**Objetivo:** Permitir uso básico do FinMe para controle de cartões, receitas e despesas.

**Status:** ✅ **Concluído**

**Funcionalidades entregues:**

- **Cadastro de cartões**
  - Múltiplos cartões cadastráveis.
  - Dados disponíveis: nome do cartão, banco, tipo, dia de vencimento e limite.

- **Cadastro de receitas e despesas**
  - Registro de transações com:
    - Valor, data, tipo (receita/despesa).
    - Forma de pagamento (crédito, débito, boleto, pix, dinheiro e outros).
    - Associação com cartão quando aplicável.
  - Provisionamento manual de gastos futuros.
  - Suporte a parcelas via campo de quantidade.

- **Categorias de despesas e receitas**
  - CRUD básico de categorias.
  - Associação de transações a categorias.

- **Visualização básica**
  - Lista filtrável por período.
  - Resumo de despesas, receitas e saldo.
  - Visualização de gastos por categoria.
  - Visualização de gastos por cartão.

- **Persistência local**
  - Dados persistidos com Hive.
  - Seeds iniciais para categorias, cartões e transações.

---

## M3 – Modo Simples vs Modo Ultra

**Objetivo:** Entregar experiências distintas de uso, respeitando o nível de complexidade desejado.

**Status:** ✅ **Concluído**

### Funcionalidades entregues ✅

| Item | Commit |
|------|--------|
| Modo Simples vs Ultra — UI adaptativa | #13, #27 |
| Persistência de preferências (modo + tema) | #38 |
| Padronização visual tema claro (tokens em `app_theme.dart`) | #28–#30 |
| Recorrência automática de transações | #39 |
| Ícones personalizados por categoria | #40 |
| Dashboard aprimorado (KPIs + gráfico de linha mensal + últimas transações) | #32, #41 |
| Tela de metas (Meta de Economia + Teto de Gastos) | #33, #44 |
| Relatórios com filtros e exportação CSV | #34 |
| Tema escuro com toggle persistido | #36 |
| Múltiplas contas/carteiras (`AccountsPage`, seed, rota `/accounts`) | #48 |
| Transferência entre contas (`TransferPage`, rota `/transfer`) | #49 |
| Splash + onboarding com seleção de modo (`OnboardingPage`, flag Hive em `HiveInit`, rota `/onboarding`) | #56+ |
| Persistência definitiva de preferências avançadas (`PreferencesService`) | concluído |
| Orçamento mensal por categoria (`BudgetPage`, `BudgetModel` typeId 6) | concluído |

> Detalhes de implementação em `docs/M3_REPORT.md`.

---

## M4 – Detecção de gastos desnecessários & análises

**Objetivo:** Ajudar o usuário a identificar desperdícios e oportunidades de economia.

**Status:** ✅ **Concluído**

**Funcionalidades entregues:**

- Identificação de assinaturas recorrentes e gastos repetitivos.
- Relatórios comparativos entre períodos.
- Visões analíticas para gastos por categoria, cartão e recorrência.
- Consolidação de indicadores para apoiar revisão de despesas.

---

## M5 – UX, visualizações e distribuição

**Objetivo:** Melhorar a experiência de uso e facilitar a adoção.

**Status:** 🟡 **Em andamento**

### M5-A — Refinamento UX/UI e visualizações iniciais ✅

**Status:** ✅ **Concluído**

**Entregas realizadas:**

- Transição de rota com slide horizontal entre páginas.
- Dashboard com KPIs animados (count-up), sparkline inline por card e toggle de séries no gráfico mensal.
- TransactionsPage com agrupamento por data e stagger de entrada nos itens.
- Bottom sheet de filtros com período, tipo e faixa de valor.
- Tipografia global com Inter.
- Varredura de espaçamentos padronizando os arquivos tocados com tokens (`AppSpacing`).

### M5-B — Próxima etapa 🔲

**Status:** 🔲 **Pendente / em definição**

**Frentes previstas para refinamento via perguntas e respostas:**

- Ajustes adicionais de UX/UI nas telas restantes.
- Linha de tempo de gastos por dia/semana/mês.
- Refinos de responsividade entre Modo Simples e Modo Ultra.
- Empacotamento `.exe` para Windows.
- Preparação de builds Android (APK/AAB para testes).

**Não incluso em M5:**

- Publicação em lojas (Microsoft Store, Google Play, App Store) – a definir.

---

## Futuro (ideias sem compromisso de prazo)

- Importação/exportação de dados (CSV, backup).
- Suporte completo a:
  - iOS / iPadOS.
  - macOS.
- Painel “Saúde financeira” com indicadores e dicas.
- Possíveis integrações com bancos, APIs de extrato ou agregadores financeiros.
- Modo “auditoria rápida” para revisar um período (ex.: últimos 15 dias) e marcar gastos como essenciais/supérfluos.
