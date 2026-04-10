# FinMe — Feature Spec: Login & Multi-Perfil por Usuário

**Versão do documento:** 1.1  
**Marco alvo:** M6  
**Status:** 🟡 Em andamento

---

## Visão Geral

Adiciona uma camada de autenticação local simples (usuário + senha, sem backend) que agrupa perfis de dados existentes. Cada **login** pode conter N **perfis**. Os dados de cada perfil continuam isolados em boxes Hive com namespace próprio — a hierarquia é `login_id → profile_id`.

O modelo anterior separava dados por perfil (`transactions_default`, `categories_demo`, etc.). Esta feature inseriu um nível acima: o box de settings sabe qual `loginId` está autenticado, e o `ProfileService` utiliza `{loginId}_{profileId}` como namespace final.

---

## Hierarquia de Dados

```
[AppData]
├── settings (box global)        ← activeLogin, activeProfile, onboardingDone
├── preferences (box global)     ← tema, moeda, idioma
├── logins (box global)          ← LoginModel { id, username, passwordHash }
├── profiles (box global)        ← ProfileModel { id, loginId, name, avatarEmoji }
│
└── [boxes namespaceados]
    ├── transactions_{loginId}_{profileId}
    ├── categories_{loginId}_{profileId}
    ├── cards_{loginId}_{profileId}
    ├── accounts_{loginId}_{profileId}
    ├── goals_{loginId}_{profileId}
    └── budgets_{loginId}_{profileId}
```

**Isolamento garantido:** cada box namespaceado com `{loginId}_{profileId}` é fisicamente separado no disco. Nenhum repositório compartilha instância de box entre perfis distintos — `RepositoryLocator.reinit` fecha os boxes anteriores antes de abrir os novos.

---

## Modelos Hive

### `LoginModel` — typeId: **7**

Arquivo: `lib/features/auth/data/login_model.dart`

```dart
@HiveType(typeId: 7)
class LoginModel {
  @HiveField(0) final String id;           // UUID v4
  @HiveField(1) final String username;     // único no box
  @HiveField(2) final String passwordHash; // SHA-256 hex; vazio = sem senha
  @HiveField(3) final DateTime createdAt;
}
```

### `ProfileModel` — typeId: **8**

Arquivo: `lib/features/auth/data/profile_model.dart`

```dart
@HiveType(typeId: 8)
class ProfileModel {
  @HiveField(0) final String id;
  @HiveField(1) final String loginId;     // FK para LoginModel
  @HiveField(2) final String name;
  @HiveField(3) final String avatarEmoji;
  @HiveField(4) final DateTime createdAt;
}
```

---

## TypeIds Consolidados

| TypeId | Classe           | Status       |
|--------|------------------|--------------|
| 0      | TransactionModel | ✅ Existente |
| 1      | *(reservado)*    | —            |
| 2      | CategoryModel    | ✅ Existente |
| 3      | CardModel        | ✅ Existente |
| 4      | AccountModel     | ✅ Existente |
| 5      | GoalModel        | ✅ Existente |
| 6      | BudgetModel      | ✅ M3-E      |
| **7**  | **LoginModel**   | ✅ M6        |
| **8**  | **ProfileModel** | ✅ M6        |

---

## Arquitetura de Serviços

### `AuthService` (`lib/core/services/auth_service.dart`)

Singleton. Responsável por register/login/logout e CRUD de perfis.

- `register(username, password)` — cria login + perfil padrão; retorna false se username duplicado
- `login(username, password)` — valida hash SHA-256; aceita senha vazia para logins migrados
- `logout()` — limpa sessão do settings sem apagar dados
- `createProfile(name, emoji)` — máx. 5 por login
- `deleteProfile(id)` — bloqueia se for o único perfil
- `switchProfile(id)` — persiste novo `activeProfile` no settings

### `ProfileService` (`lib/core/services/profile_service.dart`)

- `boxName(base, loginId, profileId)` — monta namespace `{base}_{loginId}_{profileId}`
- `loadFromStorage()` — abre boxes e chama `RepositoryLocator.reinit(loginId, profileId)`
- `switchTo(loginId, profileId)` — fecha boxes antigos antes de abrir novos

### `RepositoryLocator` (`lib/core/services/repository_locator.dart`)

- `reinit(loginId, profileId)` — inicializa todos os repositórios apontando para o namespace ativo

---

## Fluxo de Boot

```
main()
  HiveInit.init()
    └─ adapters + boxes globais (settings, preferences, logins, profiles)
    └─ Migração 1: deleta boxes legados sem sufixo (flag: profileMigrationDone)
    └─ Migração 2: promove {base}_{profileId} → {base}_{loginId}_{profileId} (flag: loginMigrationDone)

  AuthService.instance.loadFromStorage()
    └─ restaura sessão salva em settings
    └─ se login não existe mais → _activeLoginId = null

  if (isAuthenticated)
    ProfileService.instance.loadFromStorage()
      └─ abre boxes {loginId}_{profileId}
      └─ RepositoryLocator.reinit(loginId, profileId)
    DefaultSeedService.instance.seedIfEmpty()
    RecurrenceService.generatePending()

  runApp(FinMeApp(showOnboarding: ...))
    └─ initialRoute:
         showOnboarding → /onboarding
         !isAuthenticated → /login
         else → /
```

---

## Rotas

| Rota            | Tela                 | Condição                      |
|-----------------|----------------------|-------------------------------|
| `/login`        | `LoginPage`          | `!isAuthenticated`            |
| `/profile-pick` | `ProfilePickerPage`  | Pós-login, seleção de perfil |
| `/`             | `DashboardPage`      | Autenticado + perfil ativo    |

---

## Regras de Negócio

| Regra              | Detalhe                                                                    |
|--------------------|----------------------------------------------------------------------------|
| Username único     | Validado no `register()` antes de persistir (case-insensitive)            |
| Limite de perfis   | Máx. 5 por login (constante `AuthService.maxProfilesPerLogin`)            |
| Perfil padrão      | Todo login novo recebe 1 perfil automático (`"Principal"`, emoji `👤`)   |
| Exclusão de login  | Cascata: apagar login deve deletar perfis e boxes namespaceados            |
| Exclusão de perfil | Bloqueada se for o único perfil do login                                  |
| Logout             | Não apaga dados — apenas limpa `activeLogin` e `activeProfile` do settings |
| Login sem senha    | Logins migrados (`passwordHash: ''`) aceitam qualquer entrada de senha    |

---

## Segurança (Escopo Local)

- SHA-256 via pacote `crypto` — sem salt externo
- Suficiente para separação local sem transmissão de dados
- Migrar para `bcrypt` (M7+) se requisito de segurança aumentar
- Dados em `AppData` são acessíveis pelo SO — o app **não** é um cofre seguro

---

## Progresso da Feature

| #   | Subtask                                   | Status      |
|-----|-------------------------------------------|-------------|
| 1   | `LoginModel` + adapter (typeId 7)         | ✅ Concluído |
| 2   | `ProfileModel` + adapter (typeId 8)       | ✅ Concluído |
| 3   | `HiveInit` — novos boxes e adapters       | ✅ Concluído |
| 4   | Migração de namespace (2ª migration)      | ✅ Concluído |
| 5   | `AuthService` (register/login/logout)     | ✅ Concluído |
| 6   | `ProfileService` — novo `boxName(3-args)` | ✅ Concluído |
| 7   | `RepositoryLocator` — aceita namespace    | ✅ Concluído |
| 8   | `LoginPage` UI                            | ✅ Concluído |
| 9   | `ProfilePickerPage` UI                    | ✅ Concluído |
| 10  | Guardas de rota em `app.dart`             | ✅ Concluído |
| 11  | `DefaultSeedService` — recebe loginId     | ✅ Concluído |
| 12  | Testes de migração (manual)               | 🔲 Pendente |

---

## Dependências Externas Necessárias

Adicionar ao `pubspec.yaml` se ainda não presentes:

```yaml
dependencies:
  crypto: ^3.0.3
  uuid: ^4.0.0
```

---

## Próximo Passo

Subtask 12: testar manualmente o fluxo completo:
1. Instalar sobre versão antiga (com dados) — verificar que migração preserva dados
2. Criar novo usuário — verificar perfil padrão criado
3. Criar segundo perfil — verificar que dados são completamente separados
4. Logout / login — verificar que sessão é restaurada corretamente
