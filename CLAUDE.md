# CLAUDE.md
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Resumo do projeto

FinMe é um aplicativo de finanças pessoais focado em pessoas que lidam com **muitos cartões, contas e bancos**.  
O objetivo é oferecer uma visão consolidada de gastos passados, recentes e futuros, com forte suporte a:

- Vários cartões do mesmo banco e de bancos diferentes.
- Provisionamento de faturas e boletos.
- Dois modos de uso:
  - **Modo Simples** – visão enxuta para iniciantes.
  - **Modo Ultra** – visão detalhada, tipo “tanque de guerra”, para alto volume de transações.

Ao editar o código, priorize clareza de domínio (termos como cartão, fatura, boleto, provisionamento, categoria) e mantenha a lógica financeira isolada da camada de UI sempre que possível.

---

## Stack e ferramentas

- **Framework:** Flutter
- **Linguagem:** Dart
- **Plataformas alvo atuais:** Windows (desktop) e Android (mobile)
- **Plataformas futuras:** iOS / iPadOS / macOS (sem implementação obrigatória por enquanto)

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

- Listar dispositivos disponíveis:

  ```bash
  flutter devices
  ```

- Rodar em Android (quando um dispositivo/emulador estiver disponível):

  ```bash
  flutter run -d <id_do_dispositivo>
  ```

- Build de release (exemplo, ajustar conforme necessário futuramente):

  ```bash
  flutter build windows
  flutter build apk
  ```

Ao sugerir comandos, mantenha esse fluxo básico, evitando setups muito complexos a menos que o repositório seja atualizado com scripts específicos.

---

## Estrutura de código e pastas

A estrutura do projeto é organizada por núcleo (`core`) e por funcionalidades (`features`), com camadas de dados, domínio e apresentação quando fizer sentido.

Estrutura principal em `lib/`:

- `lib/app/`
  - `app.dart`: widget raiz (`MaterialApp`) e inicialização global.
  - `router.dart`: definição de rotas e navegação.

- `lib/core/`
  - `models/`: modelos genéricos e compartilhados (ex.: tipos de valor monetário, intervalos de datas).
  - `services/`: serviços reutilizáveis (ex.: abstrações de storage local, logger).
  - `utils/`: helpers e funções utilitárias.
  - `theme/`: temas, cores, tipografia e estilos globais.

- `lib/features/`
  - `cards/`
    - `data/`: repositórios e fontes de dados de cartões (ex.: storage local).
    - `domain/`: entidades e regras de negócio de cartões/bancos (limites, vencimentos, etc.).
    - `presentation/`: widgets e telas relacionados a cartões.
  - `transactions/`
    - `data/`: repositórios de receitas, despesas e boletos.
    - `domain/`: regras de negócio para transações e provisionamento.
    - `presentation/`: telas de listagem, filtros e edição de transações.
  - `categories/`
    - `data/`, `domain/`, `presentation/` para categorias de despesas/receitas.
  - `dashboard/`
    - `presentation/`: tela inicial e visões consolidadas (por período, por categoria, etc.).
  - `settings/`
    - `presentation/`: telas de configuração, incluindo toggle entre Modo Simples e Modo Ultra.

Ao sugerir novos arquivos:

- Prefira colocá-los dentro do **módulo de feature correto** (`cards`, `transactions`, `categories`, `dashboard`, `settings`).
- Separe responsabilidades:
  - **`data`**: acesso a dados, storage, repositórios.
  - **`domain`**: modelos de domínio e regras de negócio.
  - **`presentation`**: widgets, telas, lógica de UI.
- Evite criar pastas paralelas fora desse padrão sem forte justificativa.

> Nota para Claude: ao propor refactors, tente alinhar novos arquivos a essa estrutura em vez de introduzir arquiteturas completamente diferentes.

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
   - Provisionamento significa “contabilizar algo que ainda não saiu, mas já se sabe que vai sair”.

4. **Categorias**
   - Transações devem permitir associação a categorias para análise posterior.
   - A visualização por categoria é crucial (ex.: “onde estou gastando mais neste mês”).

Ao escrever código, comentários ou documentação, use essa linguagem de domínio para manter consistência.

---

## Estilo de código e boas práticas

- Siga o padrão de estilo recomendado pelo Flutter/Dart:
  - Use `dart format`/`flutter format` se for necessário formatar código.
- Prefira nomes claros e específicos:
  - `CardModel`, `Transaction`, `ExpenseCategory`, etc.
- Mantenha widgets pequenos e reutilizáveis, evitando telas monolíticas com muita lógica.

Quando sugerir refactors:

- Extrair lógica de negócio de dentro de widgets para classes de serviço ou blocos/providers (se o projeto adotar algum gerenciador de estado).
- Evitar duplicação de lógica entre Modo Simples e Modo Ultra – tente compartilhar o máximo possível de domínio e mudar apenas a apresentação.

---

## Workflow sugerido com Claude

Quando for trabalhar neste repositório:

1. **Localizar o lugar certo para a mudança**
   - Antes de criar arquivos novos, tente encontrar:
     - Modelos existentes (cartões, transações, categorias).
     - Códigos de UI já relacionados com o que está sendo alterado.

2. **Propor mudanças pequenas e incrementais**
   - Prefira PRs/commits focados (ex.: “Adicionar modelagem de boleto provisionado”).
   - Evitar refactors massivos sem necessidade.

3. **Não inventar integrações externas**
   - Não adicionar integrações com bancos, APIs externas ou scraping sem que isso esteja explicitamente pedido no código ou issues.
   - Manter o app focado em dados fornecidos pelo usuário.

4. **Privacidade e segurança**
   - Não criar fluxos que armazenem dados sensíveis em texto plano fora do escopo do app.
   - Não incluir chaves, credenciais ou segredos em código ou documentação.

---

## O que evitar

- Comentários genéricos como “escreva testes” ou “use boas práticas” sem contexto.
- Criar novas camadas arquiteturais complexas sem necessidade clara.
- Tornar o Modo Simples tão complexo quanto o Modo Ultra:
  - Modo Simples deve permanecer enxuto.
- Incluir qualquer tipo de dado real (ex.: cartões reais, bancos reais, extratos reais) em exemplos de código.

---

## Futuras extensões do CLAUDE.md

Conforme o projeto crescer, este arquivo pode ser expandido com:

- Comandos específicos de build e release (por exemplo, scripts para empacotar `.exe`).
- Padrões de commit e branch naming.
- Estratégia de testes (unitários, widget, integração).
- Convenções de navegação e temas de UI.

Mantenha este arquivo **curto, direto e atualizado**. Se algo deixar de ser válido no código, atualize o CLAUDE.md para evitar orientações obsoletas.
