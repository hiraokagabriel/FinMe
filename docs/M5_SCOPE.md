# FinMe — Marco M5: Escopo

> Criado em: 09/04/2026

## Objetivo

Refinamento final de UX/UI + empacotamento para distribuição em Windows e Android.

---

## M5-A — Refinamento UX/UI

### A1 — Consistência visual global

| Item | Problema atual | Correção |
|---|---|---|
| Estados vazios | Algumas páginas mostram lista vazia sem mensagem | Adicionar empty state padronizado em todas as páginas |
| Loading states | `CircularProgressIndicator` genérico | Skeleton loaders consistentes com a estrutura do conteúdo |
| Feedback de ações | SnackBars inconsistentes | Padronizar: sucesso (verde), erro (vermelho), info (primário) |
| Espaçamentos | Alguns widgets usam valores fora do sistema de 4px | Audit e correção para tokens `AppSpacing` |

### A2 — Dashboard

| Item | Descrição |
|---|---|
| KPI cards | Adicionar variação percentual em relação ao mês anterior |
| Gráfico de linha | Tooltip ao hover/tap com valor exato do mês |
| Últimas transações | Atalho rápido "Ver todas" linkando para `/transactions` |
| Modo Simples | Verificar se densidade baixa está correta (sem gráficos, 3 colunas) |

### A3 — Transações

| Item | Descrição |
|---|---|
| Busca global | Campo de busca por descrição no Modo Ultra |
| Filtros ativos | Indicador visual de filtros aplicados (badge no botão de filtro) |
| Swipe-to-delete | Gesto de deslizar para deletar em linha (Windows: botão hover) |
| Edição inline | Clique na linha abre form pré-preenchido |

### A4 — Formulários

| Item | Descrição |
|---|---|
| Validação | Mensagens de erro inline (não SnackBar) em todos os forms |
| Foco automático | Primeiro campo recebe foco ao abrir o form |
| Atalhos de teclado | `Enter` avança campo, `Ctrl+S` salva (desktop) |
| Confirmação de exclusão | Dialog de confirmação antes de deletar qualquer registro |

### A5 — Navegação

| Item | Descrição |
|---|---|
| Item ativo na sidebar | Highlight visual claro do item selecionado |
| Breadcrumb/título | Título da página atual sempre visível no AppBar |
| Transições | `FadeTransition` suave entre rotas (200ms) |

### A6 — Acessibilidade & Polimento

| Item | Descrição |
|---|---|
| Tooltips | Todos os botões icon-only com `Tooltip` |
| Números formatados | Valores monetários com `NumberFormat` respeitando locale |
| Scroll behavior | `ScrollbarTheme` visível no desktop |
| Janela mínima | `setMinimumSize(Size(900, 600))` no `main.dart` (Windows) |

---

## M5-B — Build Windows (.exe / MSIX)

### Pré-requisitos
- [ ] `flutter build windows --release` compila sem warnings
- [ ] `window_manager` configurado: título, tamanho mínimo, centra na abertura
- [ ] Ícone do app configurado em `windows/runner/resources/app_icon.ico`
- [ ] `pubspec.yaml`: `msix_config` ou Inno Setup script

### Empacotamento

| Opção | Ferramenta | Uso recomendado |
|---|---|---|
| MSIX | `msix` pub package | Microsoft Store / empresa |
| Installer `.exe` | Inno Setup 6 | Distribuição direta |
| Portable `.zip` | Manual (xcopy release/) | Distribuição informal |

### Critérios de aceite
- [ ] Instala em máquina limpa sem Flutter instalado
- [ ] Dados persistem em `%LOCALAPPDATA%\com.example.finme\`
- [ ] Desinstalador remove arquivos do programa (não os dados do usuário)
- [ ] Versão exibida em Configurações bate com `pubspec.yaml`

---

## M5-C — Build Android (APK de release)

### Pré-requisitos
- [ ] `flutter build apk --release` compila sem warnings
- [ ] Keystore gerado e configurado em `android/key.properties`
- [ ] `android/app/build.gradle`: `applicationId`, `versionCode`, `versionName` corretos
- [ ] Ícones gerados via `flutter_launcher_icons`
- [ ] Splash screen nativa configurada via `flutter_native_splash`

### Critérios de aceite
- [ ] APK instala em Android 8.0+ (API 26+)
- [ ] Dados persistem em armazenamento interno do app
- [ ] Navegação funciona com botão voltar do sistema
- [ ] Layout mobile-friendly: sidebar vira drawer, tabela vira lista
- [ ] Nenhum overflow em telas 360px de largura

---

## Ordem de execução sugerida

```
M5-A (UX/UI) → M5-B (Windows build) → M5-C (Android build)
```

Motivo: correções de layout do M5-A impactam diretamente o M5-C (responsividade mobile).

---

## Tabela de progresso

| # | Feature | Status |
|---|---|---|
| M5-A1 | Consistência visual global | 🔲 Pendente |
| M5-A2 | Dashboard (KPI delta, tooltip gráfico) | 🔲 Pendente |
| M5-A3 | Transações (busca, filtros, swipe) | 🔲 Pendente |
| M5-A4 | Formulários (validação inline, atalhos) | 🔲 Pendente |
| M5-A5 | Navegação (highlight, transições) | 🔲 Pendente |
| M5-A6 | Acessibilidade & polimento desktop | 🔲 Pendente |
| M5-B | Build Windows (.exe / MSIX) | 🔲 Pendente |
| M5-C | Build Android (APK release) | 🔲 Pendente |
