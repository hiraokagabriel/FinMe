# FinMe

Aplicativo Flutter de gestão financeira pessoal para **Android** e **Windows** (desktop-first).  
Foco em controle de transações, cartões de crédito, contas, categorias, recorrências, metas e relatórios.  
Toda a persistência é **100% local via Hive** — sem backend ou API externa.

> **Versão atual:** 1.0.0+1 | **Marco atual:** M3 ✅ Concluído

---

## Stack

| Camada | Tecnologia |
|---|---|
| UI / lógica | Flutter (Dart) |
| Persistência | Hive (adapters manuais, sem build_runner) |
| Gráficos | fl_chart |
| Exportação | csv |
| Estado | StatefulWidget + setState + ValueNotifier |
| Injeção | RepositoryLocator (singleton) |
| Navegação | Navigator.pushNamed + RouteObserver global |

---

## Modos de uso

### Modo Simples
Voltado para quem está começando. Baixa densidade, sem gráficos, filtros mínimos, transações provisionadas ocultas.

### Modo Ultra
"Tanque de guerra" para quem lida com muitos cartões e alto volume de transações. Alta densidade, gráficos obrigatórios, filtros completos (banco, cartão, categoria, tipo, busca global), provisionados visíveis.

A regra de ouro: máximo compartilhamento de domínio entre os modos — apenas a apresentação muda.

---

## Arquitetura

Clean Architecture por feature:

```
lib/
├── app/                        # MaterialApp, Router
├── core/
│   ├── models/                 # Money, AppMode
│   ├── services/               # HiveInit, RepositoryLocator, ThemeController,
│   │                           # AppModeController, RecurrenceService,
│   │                           # ProfileService, DefaultSeedService,
│   │                           # AuthService, RouteObserver
│   ├── theme/                  # AppTheme, tokens de cor/espaçamento/tipografia
│   └── widgets/                # AppEmptyState, AppText, etc.
└── features/
    ├── accounts/               # Contas/carteiras
    ├── auth/                   # Login / sessão
    ├── budget/                 # Orçamento mensal por categoria (M3-E)
    ├── cards/                  # Cartões de crédito/débito + faturas
    ├── categories/             # Categorias com picker de ícone
    ├── dashboard/              # KPIs + gráfico mensal + últimas transações
    ├── goals/                  # Metas de economia e teto de gastos
    ├── onboarding/             # Splash + fluxo de boas-vindas (M3-C)
    ├── payment_hub/            # Hub central de pagamentos
    ├── reports/                # Relatórios com filtros + exportação CSV
    ├── settings/               # Configurações gerais
    ├── transactions/           # CRUD completo de transações
    └── transfer/               # Transferência entre contas
```

### Convenções de nomenclatura

| Sufixo | Uso |
|---|---|
| `*_entity.dart` | Entidade pura do domínio |
| `*_model.dart` | Modelo Hive com `@HiveType`/`@HiveField` |
| `*_repository.dart` | Interface abstrata |
| `hive_*_repository.dart` | Implementação concreta Hive |
| `*_page.dart` | Tela completa |
| `*_controller.dart` | Singleton com estado global |

---

## Hive — TypeIds registrados

| TypeId | Classe |
|---|---|
| 0 | TransactionModel |
| 2 | CategoryModel |
| 3 | CardModel |
| 4 | AccountModel |
| 5 | GoalModel |
| 6 | BudgetModel |
| 1 | *(livre — evitar por precaução)* |
| 7+ | *(reservado para marcos futuros)* |

**Boxes:** `transactions`, `categories`, `cards`, `settings`, `goals`, `accounts`, `preferences`

> ⚠️ Nunca reutilizar um TypeId. O argumento de `Hive.isAdapterRegistered(n)` deve ser exatamente o typeId declarado no adapter.

---

## Rotas

| Rota | Tela |
|---|---|
| `/` | DashboardPage |
| `/transactions` | TransactionsPage |
| `/cards` | CardsPage |
| `/settings` | SettingsPage |
| `/goals` | GoalsPage |
| `/reports` | ReportsPage |
| `/accounts` | AccountsPage |
| `/transfer` | TransferPage |
| `/budget` | BudgetPage |
| `/onboarding` | OnboardingPage |
| `/login` | LoginPage |

---

## Funcionalidades implementadas

### Core / Infraestrutura
- Persistência 100% local via Hive (adapters manuais, sem build_runner)
- `RepositoryLocator` singleton para injeção de dependências
- `HiveInit` com registro de adapters + guards de typeId + migração de dados
- `DefaultSeedService`: seed automático de categorias e contas no primeiro boot
- `RecurrenceService.generatePending()`: gera transações recorrentes pendentes no boot
- `ThemeController`: tema claro/escuro com toggle persistido
- `AppModeController`: alternância Modo Simples / Modo Ultra persistida
- `RouteObserver` global (`appRouteObserver`) registrado no `MaterialApp` para reatividade entre rotas
- `AuthService`: sessão de login local com persistência
- `ProfileService`: perfil do usuário persistido

### Autenticação / Onboarding (M3-C)
- Splash screen com animação de entrada
- Fluxo de onboarding multi-etapa (boas-vindas, configuração inicial)
- Flag `isOnboardingDone` persistida no Hive — onboarding exibido apenas uma vez
- Login local com `AuthService`

### Dashboard
- KPIs: receitas, despesas e saldo do mês atual
- Gráfico de linha mensal (fl_chart)
- Lista das últimas transações
- Adaptativo por modo (Simples: KPIs; Ultra: KPIs + gráfico + lista densa)

### Transações
- CRUD completo: criação, edição, exclusão
- Tipos: `income`, `expense`, `transfer`
- Campos: `accountId`, `toAccountId`, `cardId`, `categoryId`, `notes`, `isBoleto`, `isProvisioned`, `isBillPayment`, `recurrenceRule`
- Filtros (Modo Ultra): banco, cartão, categoria, tipo, busca global, período
- Tabela adaptativa: 3 colunas (Simples) vs 5+ colunas (Ultra)
- Provisionados exibidos em itálico + ícone de relógio (Ultra)

### Transferências
- Transferência entre contas: débito na origem + crédito no destino
- Par vinculado por `transferPairId` — não duplica saldo nos cálculos

### Cartões (M3)
- CRUD de cartões de crédito e débito
- `closingDay` calculado automaticamente se não informado (`dueDay - 7`)
- **`CardStatementsPage`**: visualização de faturas por ciclo (6 ciclos, navegação por mês)
- Badge de status por fatura: Aberta · Fecha hoje · Pendente · Vencida · Paga
- **Marcar fatura como paga**: persiste flag no box `preferences` + cria transação `isBillPayment` com `id` determinístico (`bill_payment_{cardId}_{year}{mm}`)
- **Desmarcar fatura**: remove flag + remove transação de pagamento
- **`isPaid` com validação cruzada**: se a transação de pagamento for deletada externamente, a flag é limpa automaticamente — evita status "Paga" inconsistente
- Barra de limite com percentual e cor semântica (verde/amarelo/vermelho)
- Donut chart de uso do limite (Modo Ultra)
- Badge "N faturas em aberto" quando há ciclos fechados não pagos
- Badge "Em dia" quando todos os ciclos estão pagos (Modo Ultra)
- `CardsPage` implementa `RouteAware` + `didPopNext` para recarregar dados ao voltar de qualquer sub-rota

### Categorias
- CRUD completo
- Picker de ícone: emoji ou codepoint
- `CategoryIds.billPayment` reservado para pagamentos de fatura

### Contas / Carteiras
- CRUD completo
- Seed automático no primeiro boot
- Saldo calculado a partir das transações

### Metas (Goals)
- Meta de Economia: progresso baseado em receitas acumuladas
- Teto de Gastos: barra de progresso baseada em despesas do período

### Orçamento mensal (M3-E)
- `BudgetPage`: orçamento por categoria com período mensal
- `BudgetModel` (typeId 6): valor-alvo por categoria/mês
- Barra de progresso por categoria vs. gasto real

### Preferências (M3-D)
- `PreferencesService`: box `preferences` para moeda, idioma e formato de data
- Toggle de tema claro/escuro
- Toggle Modo Simples / Ultra

### Relatórios
- Filtros por período
- Gráficos de despesas por categoria
- Exportação CSV

### Notificações / Alertas
- Aviso de fatura próxima do vencimento
- Notificação de fatura vencida não paga

---

## Marcos de desenvolvimento

| Marco | Descrição | Status |
|---|---|---|
| M1 | CRUD base: transações, cartões, categorias, contas | ✅ Concluído |
| M2 | Dashboard, metas, relatórios, tema, modo Simples/Ultra | ✅ Concluído |
| M3-A | Faturas de cartão: ciclos, marcar como paga, barra de limite | ✅ Concluído |
| M3-B | Transferências entre contas, recorrência automática | ✅ Concluído |
| M3-C | Splash Screen / Onboarding | ✅ Concluído |
| M3-D | PreferencesService (moeda, idioma, formato de data) | ✅ Concluído |
| M3-E | BudgetPage — Orçamento mensal por categoria (typeId 6) | ✅ Concluído |
| M4 | Detecção de assinaturas recorrentes, relatórios de gastos desnecessários | 🔲 Pendente |
| M5 | Refinamento UX/UI, empacotamento .exe Windows, APK Android | 🔲 Pendente |

---

## Bugs corrigidos (histórico relevante)

| # | Descrição | Causa | Fix |
|---|---|---|---|
| #1 | `AppEmptyState` — argumento `subtitle:` inválido | Parâmetro renomeado para `message:` | Corrigido nos call sites |
| #2 | `CardsPage` não atualizava ao voltar de sub-rotas | `_loadData()` só chamado no `initState` | `RouteAware` + `didPopNext` via `appRouteObserver` |
| #3 | Fatura aparecia como "Paga" após deletar transação de pagamento | `isPaid` lia apenas a flag, sem validar existência da `bill_payment_*` tx | `isPaid` agora cruza flag com existência real da transação; limpa flag automaticamente se ausente |
| #4 | Crash `Cannot write, unknown type` no boot | `Hive.isAdapterRegistered(n)` com typeId errado no guard | TypeIds corrigidos para coincidir exatamente com os declarados nos adapters |

---

## Design System

**Personalidade:** clean, funcional, alta densidade de dados (referência: Linear). Sem gradientes decorativos, sombras dramáticas ou ornamentos.

**Regra de ouro:** nunca usar valores hex diretamente em widgets — sempre tokens de `lib/core/theme/app_theme.dart`.

### Paleta principal

| Token | Claro | Escuro |
|---|---|---|
| `colorBackground` | `#F5F7FA` | `#121212` |
| `colorSurface` | `#FFFFFF` | `#1E1E1E` |
| `colorPrimary` | `#42A5F5` | `#81D4FA` |
| `colorTextPrimary` | `#202124` | `#E8EAED` |
| `colorTextSecondary` | `#5F6368` | `#9AA0A6` |
| `colorWarning` | `#FF9800` | `#FFB74D` |
| `colorDanger` | `#E53935` | `#EF5350` |

### Espaçamento e bordas
- Múltiplos de `4px` (4, 8, 12, 16, 20, 24, 32…)
- `BorderRadius` de cards: `8px` | chips/badges: `4px` ou pílula
- Bordas de separação: `1px` com opacidade `0.15`
- Sombras: `elevation: 1` ou `boxShadow opacity: 0.08`
- Máx. 3 tamanhos de fonte por tela

### Tipografia

| Contexto | Tamanho | Peso |
|---|---|---|
| Título de tela | 18–20px | w600 |
| Cabeçalho de seção | 14px | w600 |
| Corpo / tabela | 13–14px | w400 |
| Apoio (datas, categorias) | 12px | w400 |
| Badge / chip | 11px | w500 |

---

## Como rodar localmente

```bash
# 1. Clonar
git clone https://github.com/hiraokagabriel/FinMe.git
cd FinMe

# 2. Instalar dependências
flutter pub get

# 3. Rodar no Windows
flutter run -d windows

# 4. Rodar no Android
flutter devices
flutter run -d <id_do_dispositivo>
```

> Se o app travar no boot após atualização de schema Hive, apague os arquivos `.hive` em `AppData\Roaming\com.example.finme\` e reinicie.

---

## Licença

A definir. Uso restrito a fins de estudo e desenvolvimento pessoal enquanto não houver `LICENSE` explícito.
