# FinMe — Marco M5: Escopo

> Atualizado em: 09/04/2026

## Objetivo

Refinamento final de UX/UI + empacotamento para distribuição em Windows e Android.

---

## M5-A1 — Consistência visual global

**Decisão:** Empty states com ícone + mensagem explicativa + botão de ação primária.

### Instrução de implementação

Criar um widget reutilizável `AppEmptyState` em `lib/core/widgets/app_empty_state.dart` com os parâmetros:
- `IconData icon` — ícone temático da seção (ex: `Icons.receipt_long_outlined` para transações)
- `String title` — título curto (ex: "Nenhuma transação")
- `String message` — descrição do que o usuário pode fazer (ex: "Adicione sua primeira transação para começar a acompanhar seus gastos.")
- `String? actionLabel` — texto do botão (nullable; se nulo, botão não renderiza)
- `VoidCallback? onAction` — callback do botão

Aplicar em **todas** as páginas que exibem listas: `TransactionsPage`, `CardsPage`, `AccountsPage`, `GoalsPage`, `BudgetPage`, `CategoriesPage`.

O botão de ação usa `ElevatedButton` com estilo do tema (não hardcode de cor). O ícone usa `AppColors` via tema, tamanho 40px. Espaçamento entre elementos: `AppSpacing.md`.

---

## M5-A2 — Dashboard

**Decisão:** KPI cards exibem variação em valor absoluto em relação ao mês anterior (ex: `+R$ 320,00` ou `-R$ 180,00`).

### Instrução de implementação

No `DashboardPage`, para cada KPI (Saldo, Receitas, Despesas):
1. Calcular o valor do mês atual e do mês anterior usando as transações já carregadas (sem nova query).
2. Exibir abaixo do valor principal: `+R$ X,XX` em `AppColors.success` se positivo, `-R$ X,XX` em `AppColors.danger` se negativo, `R$ 0,00` em `AppColors.textSecondary` se neutro.
3. Fonte: `AppText.secondary` (12px, w400). Prefixo `▲` / `▼` antes do valor.
4. Se não houver dados do mês anterior, omitir a linha (não exibir "—" ou "N/A").

Adicionar também no Dashboard um link "Ver todas →" ao final da seção "Últimas transações" que navega para `/transactions` via `Navigator.pushNamed`.

---

## M5-A3 — Transações

**Decisão:** Busca global via ícone de lupa no AppBar que expande para campo ao clicar, ocupando a linha do AppBar.

### Instrução de implementação

No `TransactionsPage` (Modo Ultra):
1. Adicionar `IconButton` com `Icons.search_outlined` no `AppBar.actions`.
2. Ao clicar, o AppBar substitui o título por um `TextField` com foco automático e botão `X` para fechar. Usar `AnimatedSwitcher` com fade 150ms para a transição.
3. O filtro atua sobre `description` (case-insensitive, sem acentuação) em tempo real via `setState`.
4. Ao fechar a busca (botão X ou `Escape`), o campo some e o título do AppBar retorna.
5. Badge de filtros ativos: se qualquer filtro estiver aplicado (banco, cartão, categoria, tipo), exibir um ponto vermelho (`AppColors.danger`, 8px) sobreposto ao ícone de filtro.

Não implementar busca no Modo Simples — apenas Modo Ultra.

---

## M5-A4 — Formulários

**Decisão:** Validação inline — mensagem de erro aparece abaixo de cada campo inválido com borda vermelha.

### Instrução de implementação

Em **todos** os formulários (`TransactionFormPage`, `CardFormPage`, `AccountFormPage`, `GoalFormPage`, `BudgetFormPage`, `CategoryFormPage`):
1. Usar `Form` + `GlobalKey<FormState>` + `TextFormField.validator` em todos os campos obrigatórios.
2. O validator retorna `String` com mensagem específica (ex: `"Informe um valor maior que zero"`, não `"Campo obrigatório"`).
3. Ao tentar salvar, chamar `_formKey.currentState!.validate()` antes de qualquer lógica de persistência. Se falso, não salvar.
4. O primeiro campo do form recebe `autofocus: true`.
5. Nos campos de valor monetário, usar `TextInputAction.next` para avançar com `Enter`; no último campo, `TextInputAction.done` chama o save.
6. Confirmação de exclusão: todo botão/ação de deletar deve exibir `showDialog` com `AlertDialog` perguntando "Deseja excluir [nome]? Esta ação não pode ser desfeita." com botões "Cancelar" e "Excluir" (este em `AppColors.danger`).

---

## M5-A5 — Navegação

**Decisão:** Fade suave de 200ms entre rotas.

### Instrução de implementação

Em `main.dart`, substituir o `onGenerateRoute` atual para usar uma `PageRouteBuilder` com `FadeTransition`:

```dart
PageRouteBuilder(
  pageBuilder: (_, __, ___) => widget,
  transitionsBuilder: (_, animation, __, child) =>
      FadeTransition(opacity: animation, child: child),
  transitionDuration: const Duration(milliseconds: 200),
)
```

Aplicar para **todas** as rotas nomeadas. Não aplicar em dialogs ou bottom sheets — esses mantêm a animação padrão do Material.

O item ativo na sidebar/NavigationRail deve usar `selectedIndex` corretamente mapeado para a rota atual via `ModalRoute.of(context)?.settings.name`.

---

## M5-A6 — Acessibilidade & Polimento desktop

**Decisão:** Sem scrollbar visível — scroll funciona normalmente, interface limpa.

### Instrução de implementação

Em `main.dart`, envolver o `MaterialApp` com:

```dart
ScrollConfiguration(
  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
  child: MaterialApp(...),
)
```

Isso remove scrollbars em todas as plataformas sem desabilitar o scroll.

Adicionar `Tooltip` em todos os `IconButton` que não possuem label visível. Convenção: usar o mesmo texto que estaria no label (ex: `tooltip: 'Adicionar transação'`).

Valores monetários: usar `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')` de `package:intl` em todos os lugares que exibem valores. Centralizar em um helper `AppFormatters.currency(double value)` em `lib/core/utils/app_formatters.dart`.

Janela mínima Windows: em `windows/runner/main.cpp` ou via `window_manager`, definir tamanho mínimo de `900x600`.

---

## M5-B — Build Windows (MSIX)

**Decisão:** MSIX — pacote moderno do Windows, instalação limpa, compatível com Microsoft Store.

### Instrução de implementação

1. Adicionar `msix: ^3.x` em `dev_dependencies` no `pubspec.yaml`.
2. Configurar bloco `msix_config` no `pubspec.yaml`:
   - `display_name: FinMe`
   - `publisher_display_name: [seu nome]`
   - `identity_name: com.example.finme`
   - `msix_version: 1.0.0.0`
   - `logo_path: assets/icons/app_icon.png` (criar ícone 512x512 PNG)
   - `capabilities: 'internetClient'` (mínimo necessário)
3. Gerar: `flutter pub run msix:create`
4. O `.msix` gerado em `build/windows/x64/runner/Release/` pode ser instalado diretamente ou submetido à Store.

### Critérios de aceite
- [ ] Instala em máquina limpa sem Flutter instalado
- [ ] Dados persistem em `%LOCALAPPDATA%\com.example.finme\`
- [ ] Desinstalador remove arquivos do programa (não os dados do usuário)
- [ ] Versão exibida em Configurações bate com `pubspec.yaml`

---

## M5-C — Build Android (APK + AAB)

**Decisão:** APK para instalação manual (sideload) + AAB para publicação na Google Play Store.

### Instrução de implementação

**Keystore:**
```bash
keytool -genkey -v -keystore finme-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias finme
```
Salvar em local seguro (fora do repositório). Configurar `android/key.properties`.

**`android/app/build.gradle`:**
- `applicationId "com.example.finme"`
- `minSdkVersion 26` (Android 8.0+)
- `targetSdkVersion 34`
- `versionCode` e `versionName` lidos do `pubspec.yaml` via `localProperties`

**Ícones:** configurar `flutter_launcher_icons` com ícone 1024x1024 PNG. Executar `flutter pub run flutter_launcher_icons`.

**Splash screen:** configurar `flutter_native_splash` com cor de fundo `#F5F7FA` (claro) e `#121212` (escuro). Executar `flutter pub run flutter_native_splash:create`.

**Responsividade mobile obrigatória:**
- Sidebar (`NavigationRail`) vira `Drawer` em telas < 600px de largura
- Tabela de transações vira lista de cards no Modo Ultra mobile
- Nenhum widget com largura fixa > 360px sem `Flexible`/`Expanded`

**Builds:**
```bash
flutter build apk --release          # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release    # → build/app/outputs/bundle/release/app-release.aab
```

### Critérios de aceite
- [ ] APK instala em Android 8.0+ (API 26+)
- [ ] AAB válido para upload na Play Store (sem erros no bundletool)
- [ ] Dados persistem em armazenamento interno do app
- [ ] Navegação funciona com botão voltar do sistema
- [ ] Nenhum overflow em telas 360px de largura

---

## Ordem de execução

```
M5-A1 → M5-A2 → M5-A3 → M5-A4 → M5-A5 → M5-A6 → M5-B → M5-C
```

Correções de layout do M5-A impactam diretamente o M5-C (responsividade mobile).

---

## Tabela de progresso

| # | Feature | Status |
|---|---|---|
| M5-A1 | Consistência visual global (AppEmptyState) | 🔲 Pendente |
| M5-A2 | Dashboard (KPI delta absoluto, link "Ver todas") | 🔲 Pendente |
| M5-A3 | Transações (busca no AppBar, badge de filtros) | 🔲 Pendente |
| M5-A4 | Formulários (validação inline, confirmação exclusão) | 🔲 Pendente |
| M5-A5 | Navegação (fade 200ms, highlight sidebar) | 🔲 Pendente |
| M5-A6 | Polimento desktop (sem scrollbar, tooltips, formatters) | 🔲 Pendente |
| M5-B | Build Windows (MSIX) | 🔲 Pendente |
| M5-C | Build Android (APK + AAB) | 🔲 Pendente |
