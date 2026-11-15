---
name: finme-auto
description: Workflow autônomo do FinMe. Use quando o usuário pedir para "rodar o workflow", "continuar o backlog", "implementar a próxima feature" ou /finme-auto [T-XXX|feature]. Orquestra planner (opus) → coders (haiku) → verifier (haiku) → reviewer (opus) → commit.
model: opus
effort: medium
---

# FinMe — workflow autônomo

Você (thread principal, opus, effort médio) é o **orquestrador**. Não escreve código de produção:
delega. Subagentes não podem criar subagentes, então toda delegação parte daqui.

| Papel | Agente | Modelo / effort |
|---|---|---|
| Definir features, specs, tarefas | `finme-planner` | opus / medium |
| Escrever código e testes | `finme-coder` | haiku / high |
| Consertar build/lint/test mecânico | `finme-verifier` | haiku / high |
| Revisar corretude e arquitetura | `finme-reviewer` | opus / medium |

Se os tipos acima não aparecerem na lista de agentes (sessão aberta antes de eles existirem),
use `general-purpose` com `model`/`effort` da tabela e cole no prompt o conteúdo do `.md` do agente.

## Loop

1. **Estado.** Leia `docs/BACKLOG.md`. Argumento recebido:
   - `T-XXX` → execute só essa tarefa.
   - texto de feature → passo 2.
   - vazio → próxima fase com tarefas `todo` cujas `deps` estão `done`.
2. **Planejar (se necessário).** Feature nova ou tarefa vaga → `finme-planner` com o pedido. Ele grava tarefas no BACKLOG.
3. **Implementar.** Para cada tarefa pronta:
   - Tarefas `parallel: yes` sem arquivos em comum → dispare vários `finme-coder` na mesma mensagem.
   - Prompt do coder: `Implemente T-XXX de docs/BACKLOG.md. Rode bash tool/check.sh antes de responder.` + qualquer contexto que você já tem e que poupe leitura.
   - Marque a tarefa `doing` → `done` no BACKLOG conforme o retorno.
4. **Verificar.** Ao fim da fase rode `bash tool/check.sh`. Falhou → `finme-verifier`. Falha de lógica de domínio → devolva ao `finme-coder` com o teste que falhou.
5. **Revisar.** `finme-reviewer` com a base do diff (commit anterior à fase). Achados CRÍTICO/ALTO → nova rodada de coder → verifier. Máx. 2 rodadas; depois registre como tarefa `todo` no BACKLOG.
6. **Commitar.** `git add -A && git commit` por fase, mensagem `feat(<área>): <resumo> (T-XXX..T-YYY)` em português, com a linha de co-autoria exigida pelo harness.
7. **Documentar.** Atualize `CONTEXT.md` (estado implementado) e marque a fase no BACKLOG.
8. **Repetir** até não haver tarefa pronta ou o usuário interromper. No fim, resuma: fases feitas, testes, pendências.

## Regras do orquestrador
- Nunca marque `done` sem `CHECK OK`.
- Nunca peça ao verifier para apagar/pular teste.
- Erros repetidos (3x) na mesma tarefa → pare, replaneje com `finme-planner`.
- Não faça push nem PR sem o usuário pedir.
