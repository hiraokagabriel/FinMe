# M8 — Visão de Faturas por Cartão

**Marco:** M8  
**Status:** 🔲 Pendente  
**Dependências:** `CardEntity` (typeId 3), box `settings` (já existente), `TransactionEntity.cardId`

---

## Objetivo

Permitir ao usuário visualizar as transações agrupadas por ciclo de fatura de cada cartão de crédito, com total do ciclo e possibilidade de marcar a fatura como paga.

---

## Navegação

Não cria rota nomeada. A tela é aberta via `MaterialPageRoute` diretamente a partir da `CardsPage`, no `onTap` de cada cartão do tipo `CardType.credit`.

```
CardsPage
  └─ tap em cartão de crédito
       └─ CardStatementsPage(card: CardEntity)
```

Cartões de débito não abrem a tela de faturas — o tap continua abrindo `NewCardPage` para edição, como hoje.

---

## Arquivos novos

| Arquivo | Responsabilidade |
|---|---|
| `lib/features/cards/domain/statement_cycle.dart` | Entidade pura do ciclo de fatura |
| `lib/features/cards/domain/statement_service.dart` | Lógica de cálculo de ciclos e persistência do status pago |
| `lib/features/cards/presentation/card_statements_page.dart` | Tela de faturas do cartão |

Nenhum novo `@HiveType` / typeId é necessário.

---

## Entidade: `StatementCycle`

```dart
// lib/features/cards/domain/statement_cycle.dart

class StatementCycle {
  final DateTime cycleStart;   // dia após o fechamento anterior
  final DateTime cycleEnd;     // dia do fechamento deste ciclo (inclusive)
  final DateTime dueDate;      // vencimento da fatura
  final double total;          // soma das despesas do ciclo
  final List<TransactionEntity> transactions;
  final bool isPaid;

  const StatementCycle({
    required this.cycleStart,
    required this.cycleEnd,
    required this.dueDate,
    required this.total,
    required this.transactions,
    required this.isPaid,
  });
}
```

---

## Serviço: `StatementService`

### Cálculo do ciclo

Dado um `CardEntity` e um mês de referência `(year, month)`:

```
closingDay = card.closingDay ?? (card.dueDay - 7).clamp(1, 28)

cycleEnd   = DateTime(year, month, closingDay)
cycleStart = DateTime(year, month - 1, closingDay) + 1 dia
dueDate    = DateTime(year, month, card.dueDay)
```

Se `closingDay >= dueDay`, o vencimento pertence ao mês seguinte:

```
dueDate = DateTime(year, month + 1, card.dueDay)
```

Transações elegíveis para o ciclo:
- `tx.cardId == card.id`
- `tx.type == TransactionType.expense`
- `tx.date >= cycleStart && tx.date <= cycleEnd`
- Provisionados são exibidos em itálico com ícone de relógio, mas incluídos no total

### Geração de múltiplos ciclos

`StatementService.cyclesForCard(card, transactions, {int count = 4})` retorna os `count` ciclos mais recentes (mês atual + 3 anteriores), ordenados do mais recente para o mais antigo.

### Persistência do status pago

Usa a box `settings` já existente. Sem novo typeId.

```
chave: "stmt_paid_${card.id}_${yyyyMM}"   ex: "stmt_paid_abc123_202604"
valor: bool (true = paga)
```

Métodos:
```dart
Future<void> markPaid(String cardId, int year, int month, bool paid);
Future<bool> isPaid(String cardId, int year, int month);
```

---

## Tela: `CardStatementsPage`

### Estrutura

```
AppBar
  title: "${card.name} — Faturas"

body: Column
  ├─ _CyclePicker           ← seletor de mês (← Abr 2026 →)
  ├─ _CycleHeader           ← período, vencimento, status badge
  ├─ Expanded > ListView    ← transações do ciclo
  └─ _CycleFooter (fixed)   ← total + botão "Marcar como paga"
```

### `_CyclePicker`

- Linha horizontal com `IconButton` chevron esquerda/direita e texto central `"MMM yyyy"` (ex: `"Abr 2026"`)
- Navega entre os ciclos gerados pelo `StatementService`
- Não permite avançar além do ciclo atual

### `_CycleHeader`

```
┌──────────────────────────────────────────────┐
│  11/mar → 10/abr          Venc. 15/abr       │
│                           [badge: Aberta]     │
└──────────────────────────────────────────────┘
```

Badge de status:

| Estado | Cor | Label |
|---|---|---|
| `isPaid == true` | `AppColors.limitLow` | Paga |
| `cycleEnd < hoje && !isPaid` | `AppColors.danger` | Vencida |
| `cycleEnd >= hoje && !isPaid` | `AppColors.warning` | Aberta |

### Lista de transações

Cada item exibe: ícone da categoria (emoji/codepoint), descrição, data, valor.  
Transações provisionadas exibidas em itálico com `Icons.schedule_outlined` à direita, como no Modo Ultra das `TransactionsPage`.

Empty state: `AppEmptyState` com ícone `Icons.receipt_long_outlined` e mensagem `"Nenhuma transação neste período"`.

### `_CycleFooter`

Barra fixa no rodapé (não scrollável):

```
┌──────────────────────────────────────────────┐
│  Total da fatura           R$ 1.234,56        │
│  [botão: Marcar como paga / Desmarcar como paga] │
└──────────────────────────────────────────────┘
```

- Botão usa `ElevatedButton` quando não paga; estilo secundário quando já paga
- Ao marcar como paga: chama `StatementService.markPaid(...)` + `setState` + SnackBar `"Fatura de abr/2026 marcada como paga"`
- Se `cycleEnd > hoje`: footer exibe label "Total parcial" ao invés de "Total da fatura"

---

## Alteração em `CardsPage`

No `itemBuilder` da `ListView`, distinguir o comportamento do `onTap`:

```dart
onTap: card.type == CardType.credit
    ? () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CardStatementsPage(card: card),
          ),
        )
    : () => _openCardForm(initial: card),
```

Adicionar hint visual no tile de cartão de crédito:
- Ícone `Icons.chevron_right` à direita
- Subtítulo inclui `· Ver faturas` ou linha separada `"Toque para ver faturas"`

---

## Subtasks de Implementação

| # | Tarefa | Arquivo |
|---|---|---|
| M8-A | `StatementCycle` entity | `domain/statement_cycle.dart` |
| M8-B | `StatementService` (cálculo + persistência) | `domain/statement_service.dart` |
| M8-C | `CardStatementsPage` | `presentation/card_statements_page.dart` |
| M8-D | Alterar `CardsPage` — onTap condicional + hint visual | `presentation/cards_page.dart` |

---

## Regras de Negócio Críticas

1. **`closingDay` nulo:** usar `(card.dueDay - 7).clamp(1, 28)` — nunca deixar negativo ou maior que 28
2. **Ciclo de virada de ano:** `DateTime(year, 0, day)` em Dart resolve corretamente para dezembro do ano anterior — sem tratamento especial
3. **Ciclo aberto (mês atual):** se `cycleEnd > hoje`, total é parcial — indicar no footer
4. **Cartões de débito:** `CardStatementsPage` não se aplica — tap abre edição normalmente
5. **`isPaid` não afeta saldo:** flag visual de controle pessoal, não cria/remove transações
