# M3 Report — FinMe

> **Gerado em:** 2026-04-05  
> **Objetivo:** Rastrear o progresso do Marco 3 (M3) item a item. Use este arquivo para solicitar commits conforme cada feature for implementada.

---

## ✅ Concluídos

| # | Feature | Commit |
|---|---------|--------|
| M3-1 | Dashboard/Home com gráfico de linha mensal | #32 |
| M3-2 | Tela de Metas (v1 + v2 unificada) | #33, #44 |
| M3-3 | Relatórios Exportáveis (filtro + CSV) | #34 |
| M3-4 | Tema Escuro com toggle | #36 |
| M3-5 | Recorrência Automática de Transações | #39 |
| M3-6 | Ícones Personalizados por Categoria | #40 |
| M3-A | Múltiplas Contas/Carteiras | #48 |
| M3-B | Transferência entre Contas | #49 |

---

## 🔲 Pendentes

### M3-C — Splash Screen / Onboarding

**Descrição:** Tela de carregamento inicial e fluxo de boas-vindas para novos usuários.

**Arquivos alvo:**
- `lib/features/onboarding/presentation/splash_page.dart` — splash animada
- `lib/features/onboarding/presentation/onboarding_page.dart` — fluxo: nome, moeda, conta inicial
- `lib/main.dart` — checar flag Hive para redirecionar splash → onboarding → home
- `lib/app/router.dart` — rotas `/splash` e `/onboarding`

**Critérios:**
- [ ] Splash exibe logo + animação por ~1.5s
- [ ] Onboarding aparece apenas no primeiro boot (flag `onboardingDone` no Hive box `settings`)
- [ ] Usuário define nome, moeda preferida e cria conta inicial
- [ ] Após onboarding, nunca mais exibe

---

### M3-D — Persistência Definitiva de Preferências Avançadas

**Descrição:** Salvar e restaurar configurações de visualização que atualmente se perdem entre sessões.

**Arquivos alvo:**
- `lib/core/services/preferences_service.dart` — singleton com Hive box `preferences`
- `lib/features/transactions/presentation/transactions_page.dart` — restaurar filtros ativos
- `lib/features/reports/presentation/reports_page.dart` — restaurar período e agrupamento

**Critérios:**
- [ ] Filtros de período, tipo e categoria persistidos entre sessões
- [ ] Ordenação preferida (por data, valor) salva
- [ ] Agrupamento de relatórios (por mês, por categoria) salvo
- [ ] Sem regressão nas preferências já existentes (tema, modo, contas)

---

### M3-E — Orçamento Mensal por Categoria

**Descrição:** Definir limite de gasto mensal por categoria, com indicador visual de uso.

**Arquivos alvo:**
- `lib/features/budget/domain/budget_entity.dart` — entidade com categoryId, limitAmount, month
- `lib/features/budget/data/budget_model.dart` — HiveType typeId=4
- `lib/features/budget/data/hive_budget_repository.dart`
- `lib/features/budget/presentation/budget_page.dart` — listagem com barras verde/amarelo/vermelho
- `lib/app/router.dart` — rota `/budget`
- `lib/core/services/hive_init.dart` — abrir box `budgets`

**Critérios:**
- [ ] CRUD de orçamentos por categoria e mês
- [ ] Indicador: verde < 75%, amarelo 75–99%, vermelho ≥ 100%
- [ ] Alerta na tela de nova transação quando categoria estiver próxima do limite
- [ ] TypeId=4 (reservado no CONTEXT.md)

---

## 📌 Ordem de Execução Sugerida

```
M3-C (Splash/Onboarding)  →  M3-D (Preferências)  →  M3-E (Orçamento)
```

M3-C é o mais independente e visível; M3-E é o mais complexo (novo model Hive + integração com transações).

---

*Após cada commit, marcar o item como ✅ acima e registrar o # do commit.*
