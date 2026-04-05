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
  - **M3: parcialmente concluído**.

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
    - `services/` (serviços genéricos, ex.: storage local, controller de modo, inicialização Hive).
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

**Observação:**

- A base de infraestrutura já suporta evolução incremental por feature.

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

**O que ainda evolui depois do M2:**

- Filtros mais avançados.
- Relatórios exportáveis.
- Modelagem mais rica para contas e transferências.

---

## M3 – Modo Simples vs Modo Ultra

**Objetivo:** Entregar experiências distintas de uso, respeitando o nível de complexidade desejado.

**Status:** 🟡 **Parcialmente concluído**

**Funcionalidades já entregues:**

- **Modo Simples**
  - Configuração nas preferências do app.
  - Interface reduzida em partes importantes da navegação.
  - Menos campos e menos informação visível em fluxos principais.
  - Filtros simplificados em transações.

- **Modo Ultra**
  - Interface com maior densidade de informações.
  - Visão de gastos por cartão e por categoria.
  - Seção de provisionados / “A vencer”.
  - Campos avançados no cadastro de transações, como cartão, parcelas e vencimento provisionado.

- **Persistência das preferências**
  - O modo atual é controlado centralmente por `AppModeController`.

- **Padronização visual do tema claro**
  - Criação de tokens visuais centralizados em `app_theme.dart`.
  - Aplicação do padrão visual nos menus e telas principais já trabalhadas na conversa:
    - dashboard
    - cartões
    - transações
    - nova transação
    - categorias
    - configurações

**Itens ainda pendentes dentro de M3:**

- Dashboard/Home aprimorado com gráfico de linha mensal.
- Tela de metas.
- Tela de relatórios exportáveis.
- Recorrência automática de transações.
- Múltiplas contas/carteiras além de cartões.
- Transferência entre contas.
- Orçamento mensal por categoria.
- Tema escuro.
- Splash / onboarding.
- Ícones personalizados por categoria.
- Persistência explícita e definitiva de preferências de visualização avançadas.

**Observação:**

- O M3 já tem base funcional e visual, mas ainda não cobre toda a visão planejada inicialmente.

---

## M4 – Detecção de gastos desnecessários & análises

**Objetivo:** Ajudar o usuário a identificar desperdícios e oportunidades de economia.

**Status:** ⏳ **Não iniciado**

**Funcionalidades planejadas:**

- Identificação de:
  - Assinaturas recorrentes (streamings, serviços, etc.).
  - Anuidades e tarifas de cartões.
- Relatórios como:
  - “Gastos recorrentes deste mês” vs meses anteriores.
  - “Top categorias onde você mais gastou neste período”.
- Visão de volume de gastos no **débito**:
  - Para onde está indo o dinheiro do dia a dia.
  - Sumarização por categoria e por estabelecimento (quando houver).

**Não incluso em M4:**

- Conexão automática com extratos bancários (tudo manual/importado pelo usuário por enquanto).
- Machine learning avançado.

---

## M5 – UX, visualizações e distribuição

**Objetivo:** Melhorar a experiência de uso e facilitar a adoção.

**Status:** ⏳ **Não iniciado**

**Funcionalidades planejadas:**

- Refinamento UX/UI:
  - Melhorias em layout, ícones, cores, responsividade.
  - Ajustes específicos para Modo Simples vs Modo Ultra.

- Visualizações gráficas:
  - Gráficos simples de categorias.
  - Linha de tempo de gastos (por dia/semana/mês).

- Distribuição:
  - Empacotar e distribuir um **.exe para Windows**.
  - Preparar base para builds Android (APK/AAB para testes).

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
