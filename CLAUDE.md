# CLAUDE.md
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Resumo do projeto

FinMe é um aplicativo de finanças pessoais focado em pessoas que lidam com **muitos cartões, contas e bancos**.  
O objetivo é oferecer uma visão consolidada de gastos passados, recentes e futuros, com forte suporte a:

- Vários cartões do mesmo banco e de bancos diferentes.
- Provisionamento de faturas e boletos.
- Dois modos de uso:
  - **Modo Simples** – visão enxuta para iniciantes.
  - **Modo Ultra** – visão detalhada, tipo "tanque de guerra", para alto volume de transações.

Ao editar o código, priorize clareza de domínio (termos como cartão, fatura, boleto, provisionamento, categoria) e mantenha a lógica financeira isolada da camada de UI sempre que possível.

---

## Stack e ferramentas

- **Framework:** Flutter
- **Linguagem:** Dart
- **Plataforma alvo:** só Windows (desktop). Outras plataformas foram removidas do projeto (`docs/V3_DIRECTION.md`).

---

## Como rodar o projeto

Assuma que os comandos são executados na raiz do repositório (onde está `pubspec.yaml`).

### Comandos principais

- Instalar dependências:

  ```bash
  flutter pub get
  ```

- Rodar em Windows (desktop):

  ```bash
  flutter run -d windows
  ```

- Build de release:

  ```bash
  flutter build windows
  ```

Ao sugerir comandos, mantenha esse fluxo básico, evitando setups muito complexos a menos que o repositório seja atualizado com scripts específicos.

---

## Padrões visuais

Esta seção define a identidade visual do FinMe. **Toda adição de UI deve seguir estas definições.** Os tokens de cor devem ser consumidos via `lib/core/theme/` — nunca use valores hex diretamente em widgets.

### Personalidade visual

O FinMe é um app **desktop de alta densidade de dados**. O tom é **sóbrio, entre sério e wabi-sabi**: neutros quentes de papel e pedra, tipografia cuidada, poucos acentos de cor, nada que pareça enfeite. Funcional e confiável como uma ferramenta profissional de gestão financeira. Sem gradientes decorativos, sem sombras excessivas, sem elementos puramente ornamentais, sem estética genérica de "template de IA". Microanimações discretas (150–200 ms) são bem-vindas quando informam mudança de estado.

### Paleta — Modo Claro

| Categoria | Token sugerido | Hex | Uso |
|---|---|---|---|
| Superfície | `colorBackground` | `#F6F5F2` | Fundo geral da janela (papel, neutro quente) |
| Superfície | `colorSurface` | `#FFFFFF` | Fundo de cartão / widget |
| Superfície | `colorSidebar` | `#ECEAE5` | Fundo da sidebar / navegação (pedra clara) |
| Marca | `colorPrimary` | `#42A5F5` | Ícones ativos, botões, barras de gráfico, links |
| Marca | `colorPrimarySubtle` | `#D3EAFD` | Fundo do item de navegação ativo |
| Conteúdo | `colorTextPrimary` | `#202124` | Títulos e textos densos |
| Conteúdo | `colorTextSecondary` | `#5F6368` | Datas, categorias, valores menores |
| Gráfico | `colorChartBar` | `#42A5F5` | Barras de gráfico (mesmo que `colorPrimary`) |
| Status | `colorWarning` | `#FF9800` | Vencimentos próximos |
| Status | `colorDanger` | `#E53935` | Faturas vencidas / perigo |

### Paleta — Modo Escuro

| Categoria | Token sugerido | Hex | Uso |
|---|---|---|---|
| Superfície | `colorBackground` | `#161514` | Fundo geral — pedra escura quente, não preto puro |
| Superfície | `colorSurface` | `#1F1E1C` | Fundo de cartão / widget |
| Superfície | `colorSidebar` | `#2A2826` | Fundo da sidebar |
| Marca | `colorPrimary` | `#81D4FA` | Azul mais claro e brilhante para contraste |
| Marca | `colorPrimarySubtle` | `#1A2D40` | Azul-escuro saturado para item ativo |
| Conteúdo | `colorTextPrimary` | `#E8EAED` | Títulos e textos — off-white suave |
| Conteúdo | `colorTextSecondary` | `#9AA0A6` | Datas, categorias, informações de apoio |
| Gráfico | `colorChartBar` | `#81D4FA` | Barras de gráfico |
| Status | `colorWarning` | `#FFB74D` | Alerta — versão mais brilhante para contraste escuro |
| Status | `colorDanger` | `#EF5350` | Perigo — versão mais brilhante para contraste escuro |

### Tipografia

- **Fontes embutidas** em `assets/fonts/` (licença OFL, arquivos `OFL-*.txt` junto), declaradas no `pubspec.yaml`. Sem pacote de fontes (nada de `google_fonts`).
  - **IBM Plex Sans** (família `IBMPlexSans`, pesos 400/500/600): toda a interface. É a fonte padrão do `ThemeData`.
  - **Source Serif 4** (família `SourceSerif4`, pesos 400/600): **só** títulos de tela e números de KPI. Consuma via `AppText.screenTitle(context)` / `AppText.kpi(context)` em `lib/core/theme/app_text.dart`; nunca escreva o nome da família em widget.
  - **Algarismos tabulares** em todo valor monetário, coluna numérica e data de tabela: `FontFeature.tabularFigures()` (helper `AppText.tabular(style)`). `MoneyText` já aplica.
- **Hierarquia de tamanhos (aproximado):**
  - Título de tela: `20px`, `FontWeight.w600`, Source Serif 4
  - Número de KPI: `22px`, `FontWeight.w600`, Source Serif 4, tabular
  - Rótulo de seção / cabeçalho de widget: `14px`, `FontWeight.w600`, `colorTextPrimary`
  - Corpo / linha de tabela: `13–14px`, `FontWeight.w400`, `colorTextPrimary`
  - Informações de apoio (datas, categorias): `12px`, `FontWeight.w400`, `colorTextSecondary`
  - Badge / chip: `11px`, `FontWeight.w500`
- **Regra geral:** não use mais de 3 tamanhos de fonte distintos em uma mesma tela (título de tela e KPI não contam).

### Espaçamento e bordas

- Use múltiplos de `4px` para padding e gap (4, 8, 12, 16, 20, 24, 32...).
- `BorderRadius` padrão de cards/widgets: `8px`.
- `BorderRadius` de chips e badges: `4px` ou `full` (pílula).
- Bordas de separação: `1px`, cor `colorTextSecondary` com opacidade `0.15`.
- Sombras: use sombras sutis (`elevation: 1` ou `boxShadow` com `opacity: 0.08`) — nunca sombras dramáticas.

### Diferenças visuais entre Modo Simples e Modo Ultra

| Elemento | Modo Simples | Modo Ultra |
|---|---|---|
| Densidade de informação | Baixa — muito espaço em branco | Alta — widgets compactos, tabelas densas |
| Sidebar | Ícones + rótulos visíveis | Ícones + rótulos visíveis + badge de contagem |
| Gráficos | Ausentes ou mínimos | Obrigatórios (barras por categoria, pizza por cartão) |
| Filtros | Apenas por período | Banco, cartão, categoria, tipo, busca global |
| Tabela de transações | 3 colunas (data, descrição, valor) | 5+ colunas (data, descrição, banco/cartão, categoria, valor) |
| Provisionados | Ocultos | Visíveis com formatação diferenciada (itálico + ícone de relógio) |
| Status de fatura | Somente valor total | Valor + barra de progresso do limite |

### Mockup de referência — Telas principais (Modo Ultra)

As descrições abaixo servem como **referência de intenção visual** para orientar a implementação das telas. Não é necessário seguir pixel a pixel, mas a estrutura e os elementos-chave devem estar presentes.

#### Tela 1 — Dashboard Consolidado

- **Estilo:** janela desktop moderna, visual clean mas denso em dados.
- **Layout:** sidebar estreita à esquerda + painel principal dividido em widgets.
- **Sidebar:** ícone de perfil no topo; botões de navegação (Dashboard, Cartões, Transações, Configurações); no rodapé, toggle proeminente com legenda "Modo: Ultra".
- **Cabeçalho:** título "FinMe — Visão Geral", seletor de período rápido ("Este Mês", "15 dias", "Personalizado"), indicador de "Saldo Consolidado Disponível".
- **Widget "Resumo de Faturas":** lista densa com avatar do banco (cor derivada do nome + iniciais; nunca logotipo real), nome do cartão, data de vencimento, valor atual da fatura e barra de progresso sutil do limite. Deve suportar 10+ linhas sem scroll interno.
- **Widget "Provisionamento de Boletos":** seção "Próximos Boletos a Vencer" com descrição, valor, data e ícone diferenciando boleto provisionado (futuro) de registrado (pago/efetivado).
- **Widget "Visão por Categoria":** gráfico de barras horizontais simples com as categorias de maior gasto no período.

#### Tela 2 — Gerenciamento de Cartões e Bancos

- **Estilo:** listagem densa com agrupamento hierárquico por banco.
- **Cabeçalho:** título "Meus Cartões e Contas" + botão "Adicionar Novo Cartão/Banco".
- **Estrutura:** cada banco é um contêiner com cabeçalho (ex.: "Banco Inter", "Nubank", "Itaú").
- **Dentro de cada banco:** mini-cartões visuais lado a lado mostrando bandeira (Mastercard/Visa), últimos 4 dígitos, tipo (Crédito/Débito), dia de vencimento e limite utilizado/total.
- **Diferencial Ultra:** badge "Assinaturas Detectadas" em cartões com assinaturas recorrentes associadas.

#### Tela 3 — Lista de Transações e Provisionamento

- **Estilo:** tabela de dados de alta densidade.
- **Barra de ferramentas:** filtros por banco, cartão, categoria, tipo (Receita/Despesa/Boleto); campo de busca global; toggle "Mostrar Provisionados".
- **Colunas da tabela:** Data, Descrição (com ícone de categoria), Banco/Cartão (com avatar do banco), Valor.
- **Diferenciação visual de linhas:**
  - Transações passadas: cinza sutil.
  - Transações recentes: cor normal.
  - Transações provisionadas (futuras): texto em itálico, fundo levemente colorido (tom de `colorWarning` com opacidade baixa) e ícone de relógio/calendário na coluna de data.
- **Rodapé:** total de despesas + total de provisionamentos para o filtro ativo.

---

## Estrutura de código (v2)

Fontes da verdade: `docs/V3_DIRECTION.md` (decisões de direção da v3; vence docs antigos em conflito), `docs/SPEC.md` (domínio e arquitetura) e `docs/BACKLOG.md` (tarefas). `CONTEXT.md` descreve o estado implementado.

- `lib/main.dart`: `runApp(bootstrap)`.
- `lib/app/`: `bootstrap.dart` (boxes `fm_*`, repositórios, seed, recorrências), `app.dart` (`FinMeApp`), `app_scope.dart` (`AppServices` + `AppScope`), `ledger.dart` (visões derivadas memoizadas), `home_shell.dart` (sidebar desktop e páginas), `seed.dart` (dados fictícios).
- `lib/core/`: `models/` (`YearMonth`, `AppSettings`), `services/` (`RecordStore`, `CollectionRepository`, `SettingsController`, `BackupService`), `theme/` (`AppColors`, `AppTheme`, `AppText`, `AppSpace`/`AppRadius`/`AppMotion`, paletas), `utils/` (formatters, date_utils, id), `widgets/` (widgets compartilhados).
- `lib/features/<f>/`: `accounts`, `cards`, `categories`, `transactions`, `recurring`, `forecast` com `domain/` e `presentation/`; `dashboard`, `settings` e `onboarding` só com `presentation/`.

Ao adicionar código:

- Coloque na feature correta. Regra de domínio vai em `domain/`; widget e tela vão em `presentation/`.
- Lógica financeira fica fora da UI, em `domain/` ou no `Ledger`. Derivados caros são memoizados no `Ledger`, nunca em `build`.
- Leitura de dados na UI: `AppScope.of(context)` + `ListenableBuilder(listenable: ledger)`.

## Workflow com agentes

- Antes de codar: leia a tarefa em `docs/BACKLOG.md` e a seção do contrato em `docs/SPEC.md`. Mudou o domínio? Atualize a SPEC primeiro.
- Fluxo autônomo: `/finme-auto [T-XXX|feature]` (skill em `.claude/skills/finme-auto`), que orquestra planner, coders, verifier e reviewer.
- Portão obrigatório: `bash tool/check.sh` deve terminar com `CHECK OK`. Não dê tarefa por concluída sem ele.
- SDK Flutter fora do PATH: `E:\Projetos\FinMe\flutter\bin`. O `tool/check.sh` acha sozinho; no Git Bash use `export PATH=/e/Projetos/FinMe/flutter/bin:$PATH`.
- Dinheiro é `int` em centavos. Formatação só em `lib/core/utils/formatters.dart`.
- `domain/`, `core/models/` e `core/utils/` são Dart puro (sem `package:flutter`).
- Cores só via `context.colors` (tokens de `lib/core/theme/`).
- Sem `withOpacity` (use `withValues(alpha:)`) e sem `DropdownButtonFormField.value` (use `initialValue`).
- Não adicione dependências. As permitidas são `hive`, `hive_flutter`, `path_provider`, `fl_chart`, `csv` e `file_selector`.
- Mês de fatura só via `lib/features/cards/domain/invoice_cycle.dart` (`invoiceDueMonth`, `installmentDueMonth`, `invoiceMonthForKey`, `purchaseDueDate`). Nunca calcule com `addMonths` à mão: com histórico de ciclo existe fatura de transição (SPEC §5.1).
- Horizonte de previsão só via `ForecastService.horizonEnd` / `Ledger.invoiceTimelineDays`; não recalcule o fim em outro lugar.
- `copyWith` de entidade com campo anulável: parâmetro `Object? x = _keep` e `identical(x, _keep)` (SPEC §4). Omitido mantém, `null` limpa.
- Worktree: novos worktrees saem de `origin/main` (v1 antiga). Rode `git reset --hard main` no branch novo antes de trabalhar.
- Coders em paralelo: arquivos disjuntos por tarefa. O portão final roda depois que todos terminam (o `check.sh` formata a árvore inteira).
- `pubspec.lock` e registrantes gerados de plugins (`windows/flutter/`) mudam com o `pub get`; não entram em commit de tarefa.

---

## Regras de domínio importantes

Ao propor modelos, funções ou fluxos, respeite:

1. **Cartões e bancos**
   - Um usuário pode ter **vários cartões por banco** e **vários bancos**.
   - Cartões podem ser de crédito ou débito; faturas valem para crédito, movimentos diretos para débito.

2. **Modos Simples e Ultra**
   - **Modo Simples**:
     - Foco em:
       - Dinheiro que sai da conta.
       - Valores de faturas principais.
     - Evitar telas e filtros muito complexos.
   - **Modo Ultra**:
     - Suportar:
       - Muitos cartões.
       - Agrupamentos por banco/cartão.
       - Provisionamento de gastos (parcelas, boletos futuros).
       - Análise de gastos desnecessários (assinaturas e anuidades).
     - A mudança de modo será feita por **toggle ou configuração** – não force o usuário a escolher em toda tela.

3. **Boletos e provisionamento**
   - Boletos podem ser registrados no momento do pagamento ou apenas provisionados.
   - Provisionamento significa "contabilizar algo que ainda não saiu, mas já se sabe que vai sair".

4. **Categorias**
   - Transações devem permitir associação a categorias para análise posterior.
   - A visualização por categoria é crucial (ex.: "onde estou gastando mais neste mês").

Ao escrever código, comentários ou documentação, use essa linguagem de domínio para manter consistência.

---

## O que evitar

- Comentários genéricos como "escreva testes" ou "use boas práticas" sem contexto.
- Criar novas camadas arquiteturais complexas sem necessidade clara.
- Tornar o Modo Simples tão complexo quanto o Modo Ultra:
  - Modo Simples deve permanecer enxuto.
- Incluir qualquer tipo de dado real (ex.: cartões reais, bancos reais, extratos reais) em exemplos de código.
- Usar valores hex diretamente em widgets — sempre consuma as cores via tokens definidos em `lib/core/theme/`.
- Adicionar gradientes decorativos, sombras dramáticas ou elementos puramente ornamentais.
