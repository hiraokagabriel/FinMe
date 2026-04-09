# FinMe — Marco M3: Relatório Final

> Atualizado em: 09/04/2026

## Status Geral

**M3 100% concluído.** Todas as features planejadas foram implementadas e verificadas no repositório.

## Features

| # | Feature | Status | Arquivo principal |
|---|---|---|---|
| M3-C | Splash Screen / Onboarding | ✅ Concluído | `lib/features/onboarding/` |
| M3-D | PreferencesService (moeda, idioma, formato de data) | ✅ Concluído | `lib/core/services/preferences_service.dart` |
| M3-E | BudgetPage — Orçamento mensal por categoria (typeId 6) | ✅ Concluído | `lib/features/budget/` |

## Outras entregas M3

| Feature | Status |
|---|---|
| Demo Mode (toggle nas configurações) | ✅ Concluído |
| Demo Seed — 12 meses de dados realistas | ✅ Concluído |
| Seed: Contas, Cartões, Categorias, Metas, Orçamentos, Transações | ✅ Concluído |
| Fix ProfileService: switch de perfil sem HiveError de tipo genérico | ✅ Concluído |

## Arquitetura M3

- `PreferencesService` usa box `preferences` (sem TypeId — box dinâmico)
- `BudgetModel` usa **typeId: 6** conforme reservado
- `ProfileService.switchTo()` fecha boxes com tipo genérico exato antes de reabrir
- `DemoSeedService` é idempotente — verifica `txBox.isNotEmpty` antes de inserir

---

## Próximo Marco

Ver [M4_SCOPE.md](./M4_SCOPE.md)
