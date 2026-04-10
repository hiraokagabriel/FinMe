# FinMe — Feature Spec: Login & Multi-Perfil por Usuário

**Versão do documento:** 1.0  
**Marco alvo:** M6 (proposto)  
**Status:** 🔲 Pendente — aprovação de design

---

## Visão Geral

Adiciona uma camada de autenticação local simples (usuário + senha, sem backend) que agrupa perfis de dados existentes. Cada **login** pode conter N **perfis**. Os dados de cada perfil continuam isolados em boxes Hive com namespace próprio — a hierarquia passa a ser `login_id → profile_id`.

O modelo atual já separa dados por perfil (`transactions_default`, `categories_demo`, etc.). Esta feature insere um nível acima: o box de settings passa a saber qual `loginId` está autenticado, e o `ProfileService` utiliza `{loginId}_{profileId}` como namespace final.

---

## Hierarquia de Dados

```
[AppData]
├── settings (box global)        ← activeLogin, onboardingDone
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

**Regra:** `ProfileService.boxName(base, profileId)` atual retorna `{base}_{profileId}`. Com a mudança, retorna `{base}_{loginId}_{profileId}`.

**Isolamento garantido:** cada box namespaceado com `{loginId}_{profileId}` é fisicamente separado no disco. Nenhum repositório compartilha instância de box entre perfis distintos — `RepositoryLocator.reinit` fecha os boxes anteriores antes de abrir os novos. Não há leitura cruzada de dados entre perfis ou entre logins.

---

## Novos Modelos Hive

### `LoginModel` — typeId: **7**

```dart
// lib/features/auth/data/login_model.dart

@HiveType(typeId: 7)
class LoginModel {
  @HiveField(0) final String id;           // UUID v4
  @HiveField(1) final String username;     // único no box
  @HiveField(2) final String passwordHash; // SHA-256 simples (sem salt externo — local only)
  @HiveField(3) final DateTime createdAt;
}
```

**Adapter:** escrito manualmente, sem build_runner. Seguir padrão de `transaction_model.dart`.  
**Box:** `logins` (global, aberto em `HiveInit.init()`).  
**Chave de registro:** `model.id`.

---

### `ProfileModel` — typeId: **8**

```dart
// lib/features/auth/data/profile_model.dart

@HiveType(typeId: 8)
class ProfileModel {
  @HiveField(0) final String id;          // UUID v4
  @HiveField(1) final String loginId;     // FK para LoginModel
  @HiveField(2) final String name;        // ex: "Pessoal", "Empresa"
  @HiveField(3) final String avatarEmoji; // ex: "💼"
  @HiveField(4) final DateTime createdAt;
}
```

**Box:** `profiles` (global, aberto em `HiveInit.init()`).  
**Chave de registro:** `model.id`.

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
| **7**  | **LoginModel**   | 🔲 Novo      |
| **8**  | **ProfileModel** | 🔲 Novo      |

---

## Mudanças em Arquivos Existentes

### `HiveInit.init()`

Adicionar:
1. Registro dos adapters `LoginModelAdapter` (typeId 7) e `ProfileModelAdapter` (typeId 8)
2. Abertura dos boxes globais `logins` e `profiles`

```dart
// Após os adapters existentes:
if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(LoginModelAdapter());
if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(ProfileModelAdapter());

await Hive.openBox<LoginModel>('logins');
await Hive.openBox<ProfileModel>('profiles');
```

Adicionar constantes:
```dart
static const String loginsBoxName   = 'logins';
static const String profilesBoxName = 'profiles';
```

---

### `ProfileService`

Substituir a constante `_kActiveProfile` por um par:

```dart
static const _kActiveLogin   = 'activeLogin';
static const _kActiveProfile = 'activeProfile'; // mantém para compatibilidade
```

Alterar `boxName`:

```dart
// ANTES
static String boxName(String base, String profileId) => '${base}_$profileId';

// DEPOIS
static String boxName(String base, String loginId, String profileId) =>
    '${base}_${loginId}_$profileId';
```

Atualizar todas as chamadas internas de `boxName` para passar `loginId`.  
`RepositoryLocator.reinit` precisa receber `loginId` e `profileId` separadamente ou um namespace pré-computado.

---

### `_migrateIfNeeded` em `HiveInit`

O namespace atual é `{base}_{profileId}`. Após a mudança, passa a ser `{base}_{loginId}_{profileId}`.

Adicionar uma **segunda migração** (nova flag `loginMigrationDone`):
- Detecta boxes no formato antigo `{base}_default` e `{base}_demo`
- Cria o login padrão (`id: 'local_default'`, sem senha) se não existir
- Move/renomeia para `{base}_local_default_default` e `{base}_local_default_demo`
- Atualiza `ProfileModel` entries correspondentes no box `profiles`

**NUNCA** reutilizar a flag `profileMigrationDone` — isso garante idempotência independente.

---

## Novo Serviço: `AuthService`

```
lib/features/auth/
├── domain/
│   └── login_entity.dart
├── data/
│   ├── login_model.dart
│   ├── login_model_adapter.dart
│   ├── profile_model.dart
│   └── profile_model_adapter.dart
└── presentation/
    ├── login_page.dart
    └── profile_picker_page.dart
```

### Responsabilidades

```dart
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? _activeLoginId;
  String? get activeLoginId => _activeLoginId;
  bool get isAuthenticated => _activeLoginId != null;

  // Cria um login novo; retorna false se username já existe
  Future<bool> register(String username, String password) async { ... }

  // Autentica; retorna false se credenciais inválidas
  Future<bool> login(String username, String password) async { ... }

  // Limpa activeLoginId e fecha boxes do login atual
  Future<void> logout() async { ... }

  // Lista perfis do login autenticado
  List<ProfileModel> profilesForActiveLogin() { ... }

  // Cria perfil vinculado ao login ativo
  Future<ProfileModel> createProfile(String name, String avatarEmoji) async { ... }
}
```

**Hash de senha:** `sha256(password)` via pacote `crypto`. Sem salt externo — aceitável para isolamento local sem transmissão de dados.

---

## Fluxo de Boot (`main.dart`)

```
HiveInit.init()
  └─ abre: settings, preferences, logins, profiles
  └─ migração de namespace se necessário

AuthService.instance.loadFromStorage()
  └─ se activeLoginId existe → verifica se login ainda existe no box
  └─ se não → _activeLoginId = null (força tela de login)

if (!isAuthenticated) → navega para LoginPage
else
  ProfileService.instance.loadFromStorage(loginId: activeLoginId)
    └─ abre boxes namespaceados com {loginId}_{profileId}
    └─ RepositoryLocator.reinit(namespace)

DefaultSeedService.seedIfEmpty()
RecurrenceService.generatePending()
runApp(...)
```

---

## Rotas Novas

| Rota                 | Tela                 | Condição                       |
|----------------------|----------------------|--------------------------------|
| `/login`             | `LoginPage`          | `!isAuthenticated`             |
| `/profile-pick`      | `ProfilePickerPage`  | Autenticado, sem perfil ativo  |
| `/settings/accounts` | (existente)          | Adicionar seção "Perfis"       |

**Guardas de rota:** verificar `AuthService.instance.isAuthenticated` em `app.dart` antes de exibir qualquer rota principal.

---

## Regras de Negócio

| Regra              | Detalhe                                                                         |
|--------------------|---------------------------------------------------------------------------------|
| Username único     | Validado no `register()` antes de persistir                                     |
| Limite de perfis   | Máx. **5 perfis por login** (configurável via constante)                        |
| Perfil padrão      | Todo login novo recebe 1 perfil automático (`"Principal"`, emoji `👤`)          |
| Exclusão de login  | Cascata: deleta todos os perfis e boxes namespaceados do login                  |
| Exclusão de perfil | Impede exclusão se for o único perfil do login                                  |
| Troca de perfil    | `ProfileService.switchTo(loginId, profileId)` fecha boxes antigos antes de abrir novos |
| Logout             | Não apaga dados — apenas limpa `activeLoginId` do settings                      |

---

## Isolamento de Dados por Perfil

Cada tela e repositório opera **exclusivamente** sobre o box do perfil ativo. O `RepositoryLocator` é a única fonte de acesso aos repositórios; após um `reinit(namespace)`, todos os repositórios apontam para os boxes do novo `{loginId}_{profileId}`. Nenhum dado de outro perfil ou login é carregado em memória enquanto não estiver ativo.

Resumo por camada:

| Camada              | Comportamento                                                      |
|---------------------|--------------------------------------------------------------------|
| **Hive (disco)**    | Boxes físicos separados por namespace — sem compartilhamento       |
| **RepositoryLocator** | Reinicializado a cada troca de perfil — aponta para o namespace ativo |
| **Apresentação**    | Todas as telas consomem repositórios via `RepositoryLocator` — sem acesso direto a boxes |
| **Settings/Preferences** | Globais — compartilhados entre todos os perfis (tema, moeda, idioma) |

---

## Segurança (Escopo Local)

- Senha não é transmitida, não fica em texto plano no Hive
- SHA-256 é suficiente para o propósito de separação local sem conectividade
- Se necessidade de segurança real surgir (M7+), migrar para `bcrypt` via `dart_bcrypt`
- Dados em `AppData` continuam acessíveis no sistema operacional — documentar na store que o app **não** é um cofre seguro

---

## Impacto em Features Existentes

| Feature              | Impacto                                                                      |
|----------------------|------------------------------------------------------------------------------|
| `DefaultSeedService` | Recebe `loginId` + `profileId` para seed no namespace correto                |
| `DemoSeedService`    | Idem — perfil demo passa a ser `{loginId}_demo`                              |
| `RecurrenceService`  | Opera sobre boxes do perfil ativo — sem mudança de interface, apenas namespace |
| `ReportsPage` (CSV)  | Nenhum impacto direto                                                        |
| `ThemeController`    | Global (box `preferences`) — sem impacto                                     |
| `AppModeController`  | Global (box `preferences`) — sem impacto                                     |

---

## Progresso da Feature

| #   | Subtask                                   | Status      |
|-----|-------------------------------------------|-------------|
| 1   | `LoginModel` + adapter (typeId 7)         | 🔲 Pendente |
| 2   | `ProfileModel` + adapter (typeId 8)       | 🔲 Pendente |
| 3   | `HiveInit` — novos boxes e adapters       | 🔲 Pendente |
| 4   | Migração de namespace (2ª migration)      | 🔲 Pendente |
| 5   | `AuthService` (register/login/logout)     | 🔲 Pendente |
| 6   | `ProfileService` — novo `boxName(3-args)` | 🔲 Pendente |
| 7   | `RepositoryLocator` — aceita namespace    | 🔲 Pendente |
| 8   | `LoginPage` UI                            | 🔲 Pendente |
| 9   | `ProfilePickerPage` UI                    | 🔲 Pendente |
| 10  | Guardas de rota em `app.dart`             | 🔲 Pendente |
| 11  | `DefaultSeedService` — recebe loginId     | 🔲 Pendente |
| 12  | Testes de migração (manual)               | 🔲 Pendente |

---

## Próximo Passo Recomendado

Iniciar pela **subtask 4** (migração de namespace) antes de qualquer modelo novo — é a operação destrutiva que protege dados existentes de usuários que já têm o app instalado.
