\# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.



\## Resumo do projeto



FinMe é um aplicativo de finanças pessoais focado em pessoas que lidam com \*\*muitos cartões, contas e bancos\*\*.  

O objetivo é oferecer uma visão consolidada de gastos passados, recentes e futuros, com forte suporte a:



\- Vários cartões do mesmo banco e de bancos diferentes.

\- Provisionamento de faturas e boletos.

\- Dois modos de uso:

&#x20; - \*\*Modo Simples\*\* – visão enxuta para iniciantes.

&#x20; - \*\*Modo Ultra\*\* – visão detalhada, tipo “tanque de guerra”, para alto volume de transações.



Ao editar o código, priorize clareza de domínio (termos como cartão, fatura, boleto, provisionamento, categoria) e mantenha a lógica financeira isolada da camada de UI sempre que possível.



\---



\## Stack e ferramentas



\- \*\*Framework:\*\* Flutter

\- \*\*Linguagem:\*\* Dart

\- \*\*Plataformas alvo atuais:\*\* Windows (desktop) e Android (mobile)

\- \*\*Plataformas futuras:\*\* iOS / iPadOS / macOS (sem implementação obrigatória por enquanto)



\---



\## Como rodar o projeto



Assuma que os comandos são executados na raiz do repositório (onde está `pubspec.yaml`).



\### Comandos principais



\- Instalar dependências:



&#x20; ```bash

&#x20; flutter pub get

&#x20; ```



\- Rodar em Windows (desktop):



&#x20; ```bash

&#x20; flutter run -d windows

&#x20; ```



\- Listar dispositivos disponíveis:



&#x20; ```bash

&#x20; flutter devices

&#x20; ```



\- Rodar em Android (quando um dispositivo/emulador estiver disponível):



&#x20; ```bash

&#x20; flutter run -d <id\_do\_dispositivo>

&#x20; ```



\- Build de release (exemplo, ajustar conforme necessário futuramente):



&#x20; ```bash

&#x20; flutter build windows

&#x20; flutter build apk

&#x20; ```



Ao sugerir comandos, mantenha esse fluxo básico, evitando setups muito complexos a menos que o repositório seja atualizado com scripts específicos.



\---



\## Estrutura de código (intenção)



A estrutura ainda pode evoluir, mas mantenha as seguintes ideias:



\- \*\*`lib/`\*\*

&#x20; - \*\*`core/`\*\* – tipos de domínio, serviços genéricos, utilitários.

&#x20; - \*\*`features/`\*\* – módulos de funcionalidade (ex.: `cards`, `transactions`, `categories`, `dashboard`).

&#x20; - \*\*`ui/` ou `presentation/`\*\* – widgets, telas, componentes de interface.



Preferir separar:



\- Domínio (regras de negócio, modelos de cartão, transação, categoria, boleto).

\- Dados (persistência, acesso a storage local, etc.).

\- Apresentação (Flutter widgets, navegação, temas).



Claude deve evitar criar estruturas completamente novas e incompatíveis com o padrão existente; prefira seguir aquilo que já estiver definido no código quando o projeto crescer.



\---



\## Regras de domínio importantes



Ao propor modelos, funções ou fluxos, respeite:



1\. \*\*Cartões e bancos\*\*

&#x20;  - Um usuário pode ter \*\*vários cartões por banco\*\* e \*\*vários bancos\*\*.

&#x20;  - Cartões podem ser de crédito ou débito; faturas valem para crédito, movimentos diretos para débito.



2\. \*\*Modos Simples e Ultra\*\*

&#x20;  - \*\*Modo Simples\*\*:

&#x20;    - Foco em:

&#x20;      - Dinheiro que sai da conta.

&#x20;      - Valores de faturas principais.

&#x20;    - Evitar telas e filtros muito complexos.

&#x20;  - \*\*Modo Ultra\*\*:

&#x20;    - Suportar:

&#x20;      - Muitos cartões.

&#x20;      - Agrupamentos por banco/cartão.

&#x20;      - Provisionamento de gastos (parcelas, boletos futuros).

&#x20;      - Análise de gastos desnecessários (assinaturas e anuidades).

&#x20;  - A mudança de modo será feita por \*\*toggle ou configuração\*\* – não force o usuário a escolher em toda tela.



3\. \*\*Boletos e provisionamento\*\*

&#x20;  - Boletos podem ser registrados no momento do pagamento ou apenas provisionados.

&#x20;  - Provisionamento significa “contabilizar algo que ainda não saiu, mas já se sabe que vai sair”.



4\. \*\*Categorias\*\*

&#x20;  - Transações devem permitir associação a categorias para análise posterior.

&#x20;  - A visualização por categoria é crucial (ex.: “onde estou gastando mais neste mês”).



Ao escrever código, comentários ou documentação, use essa linguagem de domínio para manter consistência.



\---



\## Estilo de código e boas práticas



\- Siga o padrão de estilo recomendado pelo Flutter/Dart:

&#x20; - Use `dart format`/`flutter format` se for necessário formatar código.

\- Prefira nomes claros e específicos:

&#x20; - `CardModel`, `Transaction`, `ExpenseCategory`, etc.

\- Mantenha widgets pequenos e reutilizáveis, evitando telas monolíticas com muita lógica.



Quando sugerir refactors:



\- Extrair lógica de negócio de dentro de widgets para classes de serviço ou blocos/providers (se o projeto adotar algum gerenciador de estado).

\- Evitar duplicação de lógica entre Modo Simples e Modo Ultra – tente compartilhar o máximo possível de domínio e mudar apenas a apresentação.



\---



\## Workflow sugerido com Claude



Quando for trabalhar neste repositório:



1\. \*\*Localizar o lugar certo para a mudança\*\*

&#x20;  - Antes de criar arquivos novos, tente encontrar:

&#x20;    - Modelos existentes (cartões, transações, categorias).

&#x20;    - Códigos de UI já relacionados com o que está sendo alterado.



2\. \*\*Propor mudanças pequenas e incrementais\*\*

&#x20;  - Prefira PRs/commits focados (ex.: “Adicionar modelagem de boleto provisionado”).

&#x20;  - Evitar refactors massivos sem necessidade.



3\. \*\*Não inventar integrações externas\*\*

&#x20;  - Não adicionar integrações com bancos, APIs externas ou scraping sem que isso esteja explicitamente pedido no código ou issues.

&#x20;  - Manter o app focado em dados fornecidos pelo usuário.



4\. \*\*Privacidade e segurança\*\*

&#x20;  - Não criar fluxos que armazenem dados sensíveis em texto plano fora do escopo do app.

&#x20;  - Não incluir chaves, credenciais ou segredos em código ou documentação.



\---



\## O que evitar



\- Comentários genéricos como “escreva testes” ou “use boas práticas” sem contexto.

\- Criar novas camadas arquiteturais complexas sem necessidade clara.

\- Tornar o Modo Simples tão complexo quanto o Modo Ultra:

&#x20; - Modo Simples deve permanecer enxuto.

\- Incluir qualquer tipo de dado real (ex.: cartões reais, bancos reais, extratos reais) em exemplos de código.



\---



\## Futuras extensões do CLAUDE.md



Conforme o projeto crescer, este arquivo pode ser expandido com:



\- Comandos específicos de build e release (por exemplo, scripts para empacotar `.exe`).

\- Padrões de commit e branch naming.

\- Estratégia de testes (unitários, widget, integração).

\- Convenções de navegação e temas de UI.



Mantenha este arquivo \*\*curto, direto e atualizado\*\*. Se algo deixar de ser válido no código, atualize o CLAUDE.md para evitar orientações obsoletas.

