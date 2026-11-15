# Roadmap — FinMe

Direção do produto e próximos passos. Tarefas detalhadas e status: `docs/BACKLOG.md`. Estado implementado: `CONTEXT.md`.

## Histórico

- **v1 (descontinuada)**: M1–M3 do projeto anterior. Apagada e substituída pelo rewrite v2. Docs antigos em `docs/legacy/`.

## v2 — concluída

- **Fase 0 — Fundação**: limpeza, utilitários, tema, persistência e configurações.
- **Fase 1 — Domínio**: entidades, faturas, parcelas, recorrência, saldos, categorias, previsão e correções da revisão.
- **Fase 2 — App**: bootstrap, Ledger memoizado, shell de navegação, onboarding e widgets compartilhados.
- **Fase 3 — Telas**: Painel, Previsão, Cartões, Contas, Transações, Recorrentes, Categorias e Ajustes.
- **Fase 4 — Integração**: polimento de app, dados e formulários; smoke test.
- **Fase 5 — Previsibilidade avançada**: cobertura de faturas, linha do tempo de vencimentos (60 dias), parcelas comprometidas, melhor cartão para comprar hoje e mudança de ciclo com vigência.
- **Fase 6 — Pendências conhecidas**: import de backup tudo-ou-nada, previsão cobre os 60 dias da linha do tempo, `copyWith` limpa anuláveis e fatura de transição sem fusão na mudança de ciclo (T-040..T-046).

## Próximos passos sugeridos

1. Build e teste em Android real (T-045, manual; hoje validado só em Windows).
2. Memoizar a linha de fechamentos do cartão (T-047, desempenho em volume Ultra).
3. Importação de extrato CSV/OFX, manual (o usuário escolhe o arquivo).
4. Metas de economia.
5. Auditoria rápida de gastos: essencial × supérfluo.
6. Detecção automática de assinaturas a partir do histórico de transações.
7. Distribuição do Windows: `.exe` e instalador.
