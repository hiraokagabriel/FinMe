# FinMe v3 — Direção (decidida em 2026-11-15)

Resultado do questionário de direção com o usuário. Fonte da verdade para as Fases 7–12. Quando conflitar com docs antigos, este vale.

## Premissas

- **Só Windows desktop.** Android, iOS, Linux e macOS removidos do projeto e dos docs.
- **Sempre local.** Sem rede, sem API online, sem login. Segurança e compartilhamento fora de escopo.
- Persistência continua em **Hive** (boxes novas para domínios novos; backup JSON cobre tudo).
- **Modo Simples congelado** (enxuto). ~90% do investimento vai para o **Modo Ultra**.
- Pergunta principal do app, em ordem: (1) quanto posso gastar hoje, (2) vou fechar o mês no azul, (3) onde foi meu dinheiro, (4) patrimônio total.

## Visual

- Mantém layout e estrutura. Tom: **sóbrio, entre sério e wabi-sabi**. Sem gradientes, ornamentos ou estética "AI slop".
- Tipografia (embutida como asset, licença OFL, sem dependência nova):
  - **IBM Plex Sans**: interface inteira.
  - **Source Serif 4**: só títulos de tela e números de KPI.
  - Números de tabela/valor com **algarismos tabulares** (`FontFeature.tabularFigures()`).
- Neutros quentes (papel/pedra); primário azul e status mantidos; nomes de token mantidos.
  - Claro: background `#F6F5F2`, surface `#FFFFFF`, sidebar `#ECEAE5`.
  - Escuro: background `#161514`, surface `#1F1E1C`, sidebar `#2A2826`.
- Polimento: deltas vs. mês anterior nos KPIs, sparklines, tooltips ricos, avatar de banco (cor + iniciais, nunca logo real), estados vazios com ação, skeletons, microanimações 150–200 ms, cabeçalhos de tabela fixos e ordenáveis.

## Importação (prioridade máxima)

- CSV genérico com assistente de mapeamento (data, descrição, valor ou débito/crédito, separador, formato de data, decimal) e **perfis salvos** por conta/cartão. OFX (conta e cartão). Sem PDF.
- Tela de **prévia** obrigatória, por linha:
  - categoria sugerida + origem (regra, banco, histórico, dicionário) + confiança;
  - **duplicata provável**: mesma conta, data ±1 dia, mesmo valor, descrição parecida → desmarcada por padrão;
  - **flag leve "mesmo nome + mesmo valor em qualquer data"** (recorrência ou erro) → só pede confirmação, continua marcada;
  - **casamento com provisionado** existente (mesmo valor, data próxima) → vira "confirmar provisionado";
  - **parcelas** "PARC 03/10" → cria grupo com futuras provisionadas (desligável por linha).
- Categorização automática **offline em cascata**: regras explícitas → coluna de categoria do CSV (de-para no perfil) → aprendizado pelo histórico (descrição normalizada, mais frequente, fallback por similaridade de tokens) → dicionário inicial embutido editável (padrões genéricos de estabelecimentos).
- Regras: contém / começa com / regex → categoria, tags, renomear descrição; prioridade; criar pela prévia ("sempre assim"); valem no lançamento manual; "reaplicar a transações antigas".

## Produtividade

- Paleta de comandos Ctrl+K (navegar, lançar, buscar). Atalhos: N nova transação, / buscar, 1–9 páginas.
- Multi-seleção na tabela de transações + edição em massa (recategorizar, marcar pago, tags, excluir). Edição inline de categoria e valor.

## Domínios novos

- **Subcategorias** (1 nível). Relatórios agregam no pai com drill-down.
- **Tags** livres múltiplas por transação, filtráveis em todo lugar.
- **Metas/caixinhas**: reserva virtual dentro de uma conta (alvo, data opcional, aportes/retiradas); reduz o "posso gastar"; mostra progresso e aporte mensal necessário.
- **Posso gastar hoje**: `livre = saldo contas − faturas e provisionados até a próxima receita − reservas de metas`; `por dia = livre ÷ dias até a próxima receita`. Próxima receita vem de recorrência de receita; sem ela, fim do mês. Painel: "R$ X livres · R$ Y/dia até dd/mm" com detalhamento expansível.
- **Patrimônio**: saldos de contas (automático) + ativos manuais com snapshots datados + a receber − a pagar. Gráfico de evolução mensal.
- **Devo / me devem**: pessoa, valor, data, quitar (quitar gera transação na conta escolhida).

## Relatórios

Tela curada (não construtor livre): comparativo mês a mês por categoria, tendência 12 meses, heatmap de gasto por dia, top estabelecimentos, fixo × variável, evolução de patrimônio, pivot categoria × mês. Filtros globais e export CSV em todas.

## Ordem das fases

7. Limpeza de plataformas + tipografia/paleta + polimento visual.
8. Importação + regras + categorização + prévia.
9. Produtividade (Ctrl+K, atalhos, multi-seleção, inline).
10. Subcategorias, tags, metas, "posso gastar hoje".
11. Patrimônio + devo/me devem.
12. Relatórios.

## Autonomia

Workflow `/finme-auto` por fase, `tool/check.sh` = CHECK OK em cada uma, commit por fase em `feat/v3-densidade`, sem push. Só parar em bloqueio que exija ação do usuário.
