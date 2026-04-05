# FinMe

FinMe é um aplicativo de finanças pessoais focado em pessoas que lidam com **alto volume de cartões, contas e bancos**, oferecendo uma forma clara de **provisionar** e **visualizar gastos passados, recentes e futuros** em um só lugar.

> ⚠️ Projeto em construção – uso inicial focado em desenvolvimento e experimentação.

---

## Visão geral

O objetivo do FinMe é facilitar a vida de quem precisa acompanhar **muitos cartões e contas ao mesmo tempo**, consolidando informações que normalmente ficariam espalhadas em dezenas de apps e internet bankings diferentes.

Alguns problemas que o FinMe se propõe a resolver:

- Dificuldade de acompanhar faturas de **muitos cartões** (10, 20, 30+ cartões ao mesmo tempo).
- Cansaço de abrir vários apps/bancos só para entender “quanto vou pagar este mês”.
- Falta de visão consolidada do que já foi gasto, do que ainda vai vencer e do que é supérfluo.

O app é pensado para servir **desde iniciantes em controle financeiro** até usuários avançados que precisam de uma ferramenta de “guerra” para organizar dezenas de cartões e transações.

---

## Modos de uso: Simples e Ultra

O FinMe tem dois modos de operação, pensados para perfis diferentes de usuário.

### Modo Simples

Voltado para quem está começando a organizar as finanças e não quer complexidade:

- Acompanhamento de **dinheiro que sai da conta**.
- Visualização de **valores de fatura** e compromissos básicos.
- Foco em poucos elementos na tela, sem excesso de configurações.

### Modo Ultra

Pensado como um “tanque de guerra” para quem lida com muitos cartões, contas e bancos:

- Organização de **diversos cartões**, inclusive múltiplos cartões do mesmo banco.
- Controle de **cartões de bancos diferentes** em uma visão única.
- **Provisionamento de gastos** (saber o que está por vir, não só o que já foi gasto).
- Detecção de **gastos desnecessários**, como:
  - Assinaturas esquecidas ou indesejadas.
  - Anuidades e tarifas recorrentes.
- Análise de **volume de gastos no débito** (para onde está indo o dinheiro no dia a dia).
- Registro e acompanhamento de **boletos**, tanto pagos na hora quanto provisionados.

A troca entre Modo Simples e Modo Ultra será feita via **toggle/configuração dentro do app**, permitindo que o mesmo usuário evolua de um modo para outro quando se sentir confortável.

---

## Público-alvo

- Pessoas com **muitos cartões de crédito/débito** e contas em vários bancos.
- Quem precisa consolidar e enxergar com clareza:
  - Gastos do mês.
  - Gastos da semana.
  - Períodos personalizados (15 dias, etc.).
- Usuários iniciantes em finanças (Modo Simples).
- Usuários avançados ou profissionais que lidam com **alto volume de transações** (Modo Ultra).

---

## Funcionalidades principais (MVP)

O MVP (primeira versão utilizável) do FinMe foca em:

- **Cadastro de cartões**
  - Suporte a **múltiplos cartões por banco**.
  - Organização por banco, tipo de cartão, etc.

- **Cadastro de receitas e despesas**
  - Inclusão de diferentes formas de pagamento:
    - Crédito, débito, boleto, pix, etc.
  - Registro de boletos tanto:
    - Pagos imediatamente.
    - Provisionados para datas futuras.

- **Categorias de despesas**
  - Criação e gerenciamento de categorias (ex.: alimentação, transporte, assinaturas, etc.).
  - Visualização de **quanto está sendo gasto em cada categoria**.
  - Detalhamento dentro de uma categoria (quais gastos compõem aquele total).

- **Visualização consolidada**
  - Visão de gastos:
    - Passados.
    - Recentes.
    - Provisionados/futuros.

Importação/exportação (CSV, backups, etc.) **não estará presente no MVP**, mas está prevista para versões futuras.

---

## Plataformas e tecnologia

- **Plataformas alvo**
  - Inicialmente:
    - 🪟 **Windows**
    - 🤖 **Android**
  - Futuro:
    - 🍎 **iOS / iPadOS**
    - 💻 **macOS**

- **Stack principal**
  - Aplicativo construído em **Flutter** e **Dart**.
  - Foco atual em desktop (Windows), com base de código já pensada para mobile.

---

## Estado do projeto

- Status: **Em construção**.
- Objetivo atual:
  - Estruturar a base do app (modelos, cadastro de cartões, despesas/receitas, categorias).
  - Começar pelas telas essenciais para o fluxo de quem trabalha com muitos cartões.

Este repositório é, por enquanto, **pessoal/experimental**, mas nada impede que se torne open source ou um produto mais formal no futuro.

---

## Como rodar localmente (desenvolvimento)

> 💻 Foco desta seção: **desenvolvedores**.  
> É esperado que você já tenha o **Flutter SDK** instalado e configurado no seu ambiente.

### Pré-requisitos

- Flutter instalado e configurado no seu sistema.
- Ambiente com suporte a:
  - Windows (para rodar `-d windows`).
  - Android (caso queira rodar em emulador/dispositivo Android).

### Passo a passo

1. **Clonar o repositório**

   ```bash
   git clone https://github.com/hiraokagabriel/FinMe.git
   cd FinMe
   ```

2. **Instalar dependências**

   ```bash
   flutter pub get
   ```

3. **Rodar no Windows (desktop)**

   ```bash
   flutter run -d windows
   ```

4. **Rodar em dispositivo/emulador Android (opcional)**

   Certifique-se de que há um dispositivo/emulador Android disponível e execute:

   ```bash
   flutter devices
   flutter run -d <id_do_dispositivo>
   ```

---

## Distribuição

- A ideia é oferecer futuramente um **executável (.exe)** para Windows, permitindo que usuários finais usem o FinMe sem precisar instalar Flutter ou ferramentas de desenvolvimento.
- No momento, o foco é o **fluxo de desenvolvimento via código fonte**.

---

## Roadmap (alto nível)

> Detalhes serão aprofundados em breve em um arquivo `ROADMAP.md` ou `claude.md`.

Ideias de evolução:

- ✅ MVP:
  - Cadastro de cartões.
  - Cadastro de receitas/despesas.
  - Categorias e visualização por categoria.
  - Registro e provisionamento de boletos.

- 🔜 Próximos passos:
  - Visualizações mais ricas (gráficos, dashboards simples).
  - Modo simples/ultra com experiências de interface bem diferenciadas.
  - Alertas para assinaturas e gastos recorrentes identificados como desnecessários.
  - Exportação/backup de dados.

- 🔭 Futuro:
  - Versões estáveis para Android, iOS/iPadOS e macOS.
  - Possíveis integrações com bancos ou arquivos de extrato (a avaliar).

---

## Contribuição

No momento, **o projeto não está aberto a contribuições externas**.  
Sugestões, issues e pull requests podem até ser vistos, mas não há compromisso de análise ou merge.

---

## Licença

Licença **a definir**.  
Enquanto não houver um arquivo de licença explícito (`LICENSE`), considere o uso destinado apenas a fins de estudo e desenvolvimento pessoal.

---

## Motivação

O FinMe nasceu de uma necessidade real: lidar diariamente com **mais de 50 cartões**, em múltiplos bancos, e a dificuldade de:

- Enxergar os gastos do mês de forma consolidada.
- Acompanhar gastos na semana, 15 dias, ou períodos específicos.
- Provisionar o que ainda vai vencer sem se perder entre faturas e apps.

Checar cartão por cartão manualmente gera um **cansaço desnecessário**. O FinMe é a tentativa de transformar esse caos em uma visão clara e centralizada das finanças.
