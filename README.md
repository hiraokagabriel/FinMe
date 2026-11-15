# FinMe

FinMe é um app de finanças pessoais para quem tem **muitos cartões de crédito, contas e bancos**. Ele responde à pergunta: *quanto vai sair, de onde e quando — e meu saldo aguenta?*

Tudo roda localmente, sem backend e sem integração com bancos. Os dados são os que você lança.

## Visão

Quem usa vários cartões perde a conta das faturas: cada uma fecha em um dia, vence em outro, e parcelas antigas se somam a compras novas. O FinMe junta isso numa visão só:

- **Faturas certas** por cartão, com fechamento, vencimento, parcelas e assinaturas.
- **Previsão de caixa** consolidada e por conta, com alerta de saldo negativo.
- **Cobertura de faturas**: aponta faturas próximas sem saldo previsto na conta de pagamento.
- **Provisionamento** de boletos e despesas planejadas que ainda não saíram.
- **Categorias e orçamento** mensal.

Dois modos sobre o mesmo domínio:

- **Modo Simples**: visão enxuta, com saldo, faturas e vencimentos.
- **Modo Ultra**: visão densa, com tabelas, gráficos, filtros e detalhes por cartão e conta.

## Principais recursos

- Painel com KPIs, próximas faturas, vencimentos e alertas.
- Previsão de caixa por mês e por dia, com linha do tempo de vencimentos e compromisso de parcelas.
- Cartões agrupados por banco, ciclo de fatura com vigência, pagamento de fatura e "melhor cartão para comprar hoje".
- Contas com saldo atual e previsto, transferências entre contas.
- Transações com parcelas, provisionados, boletos e filtros.
- Recorrências (assinaturas e contas fixas) com materialização automática.
- Categorias com orçamento mensal.
- Backup em JSON (exportar e importar) e exportação CSV mensal.
- Tema claro e escuro, ocultar valores, dados de exemplo fictícios para testar.

## Como rodar

Requisitos: Flutter SDK (Dart 3.11 ou superior) e, para Windows, Visual Studio com a carga de trabalho "Desktop development with C++".

```bash
flutter pub get
flutter run -d windows
```

## Build

```bash
flutter build windows
```

## Testes

```bash
flutter test
```

Para o portão completo (format, analyze e test):

```bash
bash tool/check.sh
```

O script termina com `CHECK OK` quando tudo passa.

## Estrutura

```
lib/
  main.dart        ponto de entrada
  app/             bootstrap, Ledger (visões derivadas), escopo de serviços, shell de navegação, seed
  core/            modelos, persistência, tema, utilitários e widgets compartilhados
  features/        accounts, cards, categories, transactions, recurring, forecast, dashboard, settings, onboarding
                   (cada feature: domain/ em Dart puro e presentation/)
test/              espelha lib/
docs/
  SPEC.md          especificação de domínio, arquitetura e telas
  V3_DIRECTION.md  decisões de direção da v3 (vence docs antigos)
  BACKLOG.md       tarefas e status
  legacy/          documentos da v1 (descontinuada)
```

Estado atual, regras financeiras e histórico: [CONTEXT.md](CONTEXT.md). Direção e próximos passos: [ROADMAP.md](ROADMAP.md).

## Especificação

O contrato de domínio e de arquitetura está em [docs/SPEC.md](docs/SPEC.md). Mudanças de regra financeira começam pela SPEC.

## Plataformas

Só Windows (desktop). Outras plataformas foram removidas do projeto (ver `docs/V3_DIRECTION.md`).

## Privacidade

Os dados ficam no computador (Hive). Os exemplos e o modo de dados de exemplo usam nomes fictícios ("Banco Alfa", "Banco Beta"). Nenhum dado bancário real é incluído no repositório.
