# Troubleshooting – FinMe

Este documento registra problemas reais encontrados durante o desenvolvimento do FinMe e suas soluções.  
Use-o como referência rápida antes de perder tempo com erros já resolvidos.

> Dica: sempre copie a mensagem de erro completa e anote o que você fez para resolver.

---

## 1. Git / Repositório

### 1.1. Erro ao dar `git push`: "fetch first / remote contains work that you do not have locally"

**Mensagem típica:**

```text
! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'https://github.com/...'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. This is usually caused by another repository pushing to
hint: the same ref. If you want to integrate the remote changes, use
hint: 'git pull' before pushing again.
```

**Causa:**

- O repositório remoto no GitHub já tinha commits (ex.: README criado pelo GitHub), e o branch local não tinha esses commits na história.

**Solução recomendada:**

1. Puxar as mudanças do remoto com rebase:

   ```bash
   git pull --rebase origin main
   ```

2. Resolver conflitos, se existirem (normalmente em README), e continuar o rebase:

   ```bash
   git add <arquivos>
   git rebase --continue
   ```

3. Fazer o push:

   ```bash
   git push -u origin main
   ```

**Observação:** use `git push --force` apenas se tiver certeza de que quer sobrescrever o histórico remoto.

---

### 1.2. Confusão entre repositório pai e submódulo `FinMe`

**Sintomas:**

- Rodar `git status` na raiz mostrava algo como:

  ```text
  Changes not staged for commit:
        modified:   FinMe (new commits)
  ```

- `flutter run` mostrava o app Flutter padrão ("Flutter Demo Home Page") mesmo após mudar `main.dart`.

**Causa:**

- Estava sendo usado um repositório "pai" que contém o projeto Flutter real como submódulo na pasta `FinMe/`.
- Os comandos `flutter run`, `git pull`, etc. estavam sendo executados na pasta errada (na raiz, e não dentro de `FinMe`).

**Solução:**

1. Entrar na pasta correta do projeto Flutter (submódulo):

   ```bash
   cd FinMe
   git status
   ```

2. Rodar os comandos sempre dentro dessa pasta (onde está `pubspec.yaml`):

   ```bash
   git pull origin main
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

---

## 2. Flutter / Build

### 2.1. App continua mostrando "Flutter Demo Home Page" mesmo após mudar o código

**Sintomas:**

- `flutter run` abre sempre o app padrão com contador, mesmo depois de mudar `main.dart`.

**Possíveis causas e soluções:**

1. **Projeto errado:**
   - Verificar se você está na pasta que contém o `pubspec.yaml` correto (ver seção 1.2 sobre submódulos).

2. **Build antigo em cache:**
   - Rodar:

     ```bash
     flutter clean
     flutter pub get
     flutter run -d windows
     ```

3. **`main.dart` errado sendo executado:**
   - Garantir que o arquivo de entrada é `lib/main.dart` do projeto correto.

---

### 2.2. Erro de compilação com `DateRange`: "Method invocation is not a constant expression"

**Mensagem típica:**

```text
lib/core/models/date_range.dart(6,21): error ... Method invocation is not a constant expression.
```

**Código problemático:**

```dart
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end})
      : assert(!end.isBefore(start), 'end must be on or after start');
}
```

**Causa:**

- Construtor marcado como `const` com um `assert` chamando método (`end.isBefore(start)`), o que não é permitido em contexto `const`.

**Solução:**

- Remover o `const` do construtor:

  ```dart
  class DateRange {
    final DateTime start;
    final DateTime end;

    DateRange({required this.start, required this.end})
        : assert(!end.isBefore(start), 'end must be on or after start');
  }
  ```

---

### 2.3. Erro de string com "R$" em interpolação

**Mensagem típica:**

- Erro na linha com `'R$'` dentro de uma string interpolada:

```dart
final amountText = '$sign R$ ${tx.amount.amount.toStringAsFixed(2)}';
```

**Causa:**

- Em Dart, o símbolo `$` dentro de strings tem significado especial (interpolação) e precisa ser escapado quando usado como caractere literal.

**Solução:**

- Escapar o `$` usando `\$`:

  ```dart
  final amountText = '$sign R\$ ${tx.amount.amount.toStringAsFixed(2)}';
  ```

- Mesmo ajuste foi aplicado em outras strings com valores monetários.

---

### 2.4. Erros de import / tipos não encontrados

**Exemplos de mensagens:**

```text
Undefined name 'CardType'.
Type 'TransactionsRepository' not found.
Error when reading '.../transactions_repository.dart': The system cannot find the path specified
```

**Causas comuns:**

- Caminhos relativos de import incorretos ao reorganizar pastas (`features/.../data`, `domain`, `presentation`).
- Esquecer de importar o arquivo onde o tipo está definido (ex.: usar `CardType` sem importar `card_type.dart`).

**Soluções aplicadas:**

- Ajustar imports em arquivos de apresentação para usar caminhos corretos, por exemplo:

  ```dart
  // Dentro de lib/features/transactions/presentation/transactions_page.dart
  import '../data/transactions_repository.dart';
  import '../domain/transaction_entity.dart';
  import '../domain/transaction_type.dart';
  import '../../categories/data/categories_repository.dart';
  import '../../categories/domain/category_entity.dart';
  ```

- Adicionar imports ausentes, por exemplo, em `cards_repository.dart`:

  ```dart
  import '../domain/card_entity.dart';
  import '../domain/card_type.dart';
  ```

---

## 3. Boas práticas ao debugar

1. **Leia o caminho completo do arquivo e a linha do erro**
   - Muitas vezes o problema é só um import ou um caminho de arquivo errado.

2. **Confira a estrutura de pastas**
   - Compare com o que está documentado em `CLAUDE.md` e `ROADMAP.md`.

3. **Depois de mudanças grandes em estrutura**
   - Sempre rode:

     ```bash
     flutter clean
     flutter pub get
     ```

4. **Quando em dúvida sobre o estado do Git**
   - Use:

     ```bash
     git status
     git remote -v
     ```

5. **Documente erros novos aqui**
   - Ao encontrar um problema novo, adicione:
     - Mensagem de erro.
     - Causa (quando descobrir).
     - Solução aplicada.

Isso ajuda a manter o histórico de aprendizado do projeto e acelera a resolução de problemas futuros.
