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

## v3 — concluída (`docs/V3_DIRECTION.md`)

- **Fase 7 — Identidade visual e polimento**: tipografia Plex + Source Serif 4, neutros quentes, deltas/sparklines, avatar de banco, ordenação, estados vazios, shell só desktop (T-050..T-068).
- **Fase 8 — Importação, regras e categorização**: CSV com perfis, OFX, prévia com deduplicação, casamento com provisionados e parcelas, categorização offline em cascata, regras e dicionário editáveis (T-070..T-092).
- **Fase 9 — Produtividade**: paleta Ctrl+K, atalhos globais, multi-seleção com ações em massa e edição inline (T-100..T-115).
- **Fase 10 — Subcategorias, tags, metas e "posso gastar hoje"** (T-120..T-142).
- **Fase 11 — Patrimônio e devo/me devem** (T-150..T-164).
- **Fase 12 — Relatórios**: 7 relatórios curados com filtros globais e CSV (T-170..T-190). **v3 concluída.**
- **Fase 14 — Perfis**: vários perfis com dados isolados e PIN opcional (T-230..T-233).

## Próximos passos sugeridos

Direção da v3 (Fases 7–12): `docs/V3_DIRECTION.md`. Fase 7 (identidade visual e polimento) está no `docs/BACKLOG.md`.

1. Memoizar a linha de fechamentos do cartão (T-047, desempenho em volume Ultra).
2. Importação de extrato CSV/OFX, manual (o usuário escolhe o arquivo).
3. Metas de economia.
4. Auditoria rápida de gastos: essencial × supérfluo.
5. Detecção automática de assinaturas a partir do histórico de transações.
6. Distribuição do Windows: `.exe` e instalador.
