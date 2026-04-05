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

- Status: **Em construção** (MVP em desenvolvimento).
- Plataforma principal atual: **Windows (desktop)**.
- Público alvo inicial: usuário final avançado (quem trabalha com muitos cartões), mas com espaço para iniciantes via Modo Simples.

---

## M1 – Infraestrutura básica & setup de desenvolvimento

**Objetivo:** Ter um projeto Flutter estruturado, rodando em desktop, com base para evolução.

**Itens previstos:**

- Projeto Flutter criado e versionado no GitHub.
- Organização inicial de pastas em `lib/`:
  - `lib/app/`
    - `app.dart` (widget raiz, `MaterialApp`).
    - `router.dart` (definição de rotas/navegação).
  - `lib/core/`
    - `models/` (modelos genéricos, ex.: Money, DateRange).
    - `services/` (serviços genéricos, ex.: storage local, logger).
    - `utils/` (helpers e funções utilitárias).
    - `theme/` (cores, tipografia, temas).
  - `lib/features/`
    - `cards/` (cartões e bancos – `data/`, `domain/`, `presentation/`).
    - `transactions/` (receitas, despesas, boletos – `data/`, `domain/`, `presentation/`).
    - `categories/` (categorias de despesa/receita – `data/`, `domain/`, `presentation/`).
    - `dashboard/` (tela inicial e visões consolidadas – `presentation/`).
    - `settings/` (configurações do app, incluindo Modo Simples/Ultra – `presentation/`).

- Tela inicial simples em `features/dashboard/presentation` com:
  - Placeholder para o dashboard financeiro futuro.
  - Navegação básica (por exemplo, para telas de cartões e transações).

**Não incluso em M1:**

- Regras complexas de domínio financeiro.
- Persistência definitiva (pode ser em memória ou mocks).

---

## M2 – Núcleo financeiro (MVP funcional)

**Objetivo:** Permitir uso básico do FinMe para controle de cartões, receitas e despesas.

**Funcionalidades planejadas:**

- **Cadastro de cartões**
  - Múltiplos cartões por banco.
  - Dados mínimos: nome do cartão, banco, tipo (crédito/débito), dia de vencimento, limite opcional.

- **Cadastro de receitas e despesas**
  - Registro de transações com:
    - Valor, data, tipo (receita/despesa).
    - Forma de pagamento (crédito, débito, boleto, pix, etc.).
    - Associação a um cartão/conta quando aplicável.
  - Registro de boletos:
    - Pagos na hora.
    - Provisionados para data futura.

- **Categorias de despesas**
  - CRUD básico de categorias.
  - Associação de transações a categorias.

- **Visualização básica**
  - Lista filtrável por período (mês, semana, datas customizadas).
  - Total de gastos por categoria em um período.

**Não incluso em M2:**

- Modo Ultra completo (apenas estrutura inicial).
- Visualizações avançadas (gráficos complexos, dashboards detalhados).

---

## M3 – Modo Simples vs Modo Ultra

**Objetivo:** Entregar experiências distintas de uso, respeitando o nível de complexidade desejado.

**Funcionalidades planejadas:**

- **Modo Simples**
  - Configuração via toggle ou ajuste nas preferências do app.
  - Interface reduzida com foco em:
    - Dinheiro que sai da conta.
    - Valores de faturas principais.
  - Menos campos/menos telas.

- **Modo Ultra**
  - Interface com maior densidade de informações:
    - Vários cartões por banco e entre bancos.
    - Visão de gastos por cartão, por banco e consolidado.
    - Provisionamento de gastos futuros (parcelas, boletos vencendo).
  - Análise de gastos desnecessários (assinaturas e anuidades).
  - Configuração de colunas e filtros avançados.

- **Persistência das preferências**
  - Lembrar qual modo o usuário utilizou por último.
  - Persistir configurações básicas de visualização.

**Não incluso em M3:**

- Recomendações automáticas ou IA.
- Integrações com bancos ou APIs externas.

---

## M4 – Detecção de gastos desnecessários & análises

**Objetivo:** Ajudar o usuário a identificar desperdícios e oportunidades de economia.

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
