# M6 – Overhaul de Contas, Cartões e Fluxos de Pagamento

> Status: rascunho inicial – escopo aprovado pelo owner, implementação em progresso.

## 1. Problemas atuais

### 1.1 Sintomas observados

- Pagamento de fatura de cartão não "libera" o limite de forma clara para o usuário.
- Mesma informação financeira aparece em telas diferentes com cálculos ligeiramente distintos (CardsPage, CardStatementsPage, Reports, Dashboard).
- Transações de pagamento de fatura aparecem como despesas genéricas na aba de transações, sem origem/destino óbvio.
- A relação entre **contas** (dinheiro real), **cartões** (crédito) e **transações** não é explícita no domínio.

### 1.2 Causas técnicas

- Lógica de negócios espalhada por múltiplas telas e services (CardsPage, PaymentHubService, StatementService, Reports), sem uma fonte única de verdade.
- Ausência de um modelo de domínio explícito para **"fluxo de dinheiro"** (de onde o dinheiro sai e para onde vai) em pagamentos de fatura.
- Uso de flags (`isBillPayment`, `isProvisioned`) sem invariantes documentadas.
- Cálculos de limite e saldo feitos "ad hoc" em diferentes lugares.

---

## 2. Objetivos do overhaul

1. **Unificar o modelo de domínio** para contas, cartões e transações.
2. **Garantir rastreabilidade**: todo valor mostrado na UI é derivável de um conjunto claro de transações.
3. **Eliminar duplicidade/confusão** entre telas: mesma métrica = mesmo cálculo.
4. **Comportamento previsível** alinhado com apps bancários atuais:
   - Cartão de crédito consome **limite**, não saldo imediato de conta.
   - Pagamento de fatura é uma saída clara de uma conta específica.
   - Transferências não podem ser contadas duas vezes.
5. **Não quebrar dados existentes** (Hive) e manter upgrades seguros.

---

## 3. Modelo de domínio alvo

### 3.1 Contas (`AccountEntity`)

- Representam "dinheiro real" (corrente, poupança, dinheiro físico, investimento etc.).
- Não armazenam saldo atual; o saldo é **derivado**:

  ```
  saldo = initialBalance
        + soma(income em accountId)
        - soma(expense em accountId)
        - soma(transfer out: accountId -> toAccountId)
        + soma(transfer in: outra accountId -> toAccountId == esta)
        - soma(card bill payments em accountId)
  ```

- Invariantes:
  - Toda transação que mexe com dinheiro de conta deve ter `accountId` preenchido.
  - Nenhuma transação deve "ajustar saldo" por fora.

### 3.2 Cartões (`CardEntity`)

- Cartão de crédito tem:
  - `limit`: limite total.
  - `dueDay` e `closingDay`: definem ciclos (faturas).
- Cartão **não tem saldo** próprio; a "dívida" é derivada de transações de cartão + status das faturas.

- Limite comprometido passa a ser calculado sempre pela mesma regra:

  ```
  committed =
    gastos ciclo aberto (despesas de cartão, não provisionadas, !isBillPayment)
  + gastos ciclos fechados NÃO pagos (mesma filtragem)

  usedRatio = committed / limit
  ```

- Invariantes:
  - Compras com cartão: `cardId` preenchido, `accountId` normalmente nulo.
  - Pagamento de fatura: `cardId` + `accountId` preenchidos, `isBillPayment = true`.

### 3.3 Transações (`TransactionEntity`)

Tipos principais (`TransactionType`):

- `income`: entrada de dinheiro em uma conta (`accountId` obrigatório).
- `expense`: saída de dinheiro de conta **ou** gasto em cartão.
- `transfer`: saída e entrada entre contas (`accountId` + `toAccountId`).

Flags e invariantes:

- `isProvisioned = true` → transação "fantasma" futura, não afeta saldo nem limite até ser concretizada.
- `isBillPayment = true` → sempre:
  - `type == TransactionType.expense`.
  - `cardId != null`.
  - `accountId != null` (conta de débito).
  - `recurrenceRule == RecurrenceRule.none`.

---

## 4. Regras de cálculo consolidadas

### 4.1 Saldo de conta

Sempre derivado de `TransactionEntity`, conforme fórmula da seção 3.1, com as seguintes regras:

- Ignorar `isProvisioned == true`.
- Incluir `isBillPayment == true` como despesa real da conta.
- Transferências tratadas como saída + entrada, sem somar duas vezes.

### 4.2 Limite de cartão

- Limite comprometido (`totalCommitted`) =
  - ciclo aberto atual (gastos com cartão entre último fechamento e próximo fechamento),
  - + todos os ciclos fechados onde `isPaid == false`.
- Limite disponível = `max(0, limit - totalCommitted)`.
- Pagamento de fatura:
  - Marca `isPaid = true` para o ciclo.
  - Cria transação `isBillPayment` vinculada à conta selecionada.
  - Remove aquele ciclo do cálculo de `totalCommitted`.

### 4.3 Relatórios e dashboard

- Todos os relatórios que exibem gastos por conta:
  - Devem incluir `isBillPayment` (é saída real de dinheiro).
  - Não devem incluir compras de cartão (`cardId != null` e `accountId == null`).
- Todos os relatórios que exibem gastos de cartão:
  - Devem considerar apenas transações com `cardId != null` e `!isBillPayment`.

---

## 5. UX / comportamento esperado

### 5.1 Pagamento de fatura

- Usuário vê fatura pendente na **Central de Pagamentos** (PaymentHub) ou nas faturas do cartão.
- Ao tocar em "Marcar como pago":
  - Abre modal com lista de contas.
  - Usuário escolhe a conta de débito.
  - Sistema cria transação `isBillPayment` vinculada à conta e ao cartão.
  - Fatura passa a `isPaid = true` e sai da lista de pendências.
  - Cartão tem limite imediatamente atualizado na página de cartões.

### 5.2 Tela de transações

- Pagamentos de fatura aparecem claramente como uma linha do tipo:
  - Descrição: `Fatura <nome do cartão>`.
  - Ícone/categoria específica (ex: "Pagamento de fatura").
- Usuário consegue entender, olhando apenas a lista, por que o saldo da conta mudou.

### 5.3 Evitar duplicidade de informação

- Mesma métrica não será reimplementada em cada tela.
  - Exemplo: cálculo de `totalCommitted` deve ficar em um service de domínio reutilizável.
- Telas consomem **view models** já processados, em vez de recalcularem lógica de negócio.

---

## 6. Plano de implementação (M6 – Contas & Cartões)

### 6.1 Refactor de domínio

- [x] Documentar modelo alvo e invariantes (este arquivo).
- [ ] Extrair serviço de cálculo de saldo de conta (ex: `AccountBalanceService`).
- [ ] Extrair serviço de cálculo de limite de cartão (ex: `CardLimitService`) em vez de lógica dentro de `CardsPage`.
- [ ] Centralizar criação de `TransactionEntity` de pagamento de fatura em um único service.

### 6.2 Pagamento de fatura

- [x] `StatementService.markPaid` passa a aceitar `accountId` e criar transação `isBillPayment` vinculada à conta.
- [x] `PaymentHubPage` exibe bottom sheet para escolher conta antes de marcar fatura como paga.
- [ ] `CardStatementsPage` deve usar o mesmo fluxo de seleção de conta (ou delegar para `PaymentHub`).

### 6.3 UI / Experiência

- [ ] Ajustar TransactionsPage para exibir pagos de fatura com categoria/ícone próprio.
- [ ] Garantir que compras de cartão não contam em relatórios de conta.
- [ ] Revisar ReportsPage para usar os mesmos serviços de cálculo adotados em AccountsPage e CardsPage.

### 6.4 Garantias e testes manuais

- [ ] Verificar migração suave de dados existentes (sem necessidade de mudar modelos Hive – apenas comportamento).
- [ ] Casos de teste manuais:
  - Criar compras com cartão, fechar fatura, pagar de conta corrente e conferir:
    - saldo da conta,
    - limite comprometido do cartão,
    - relatórios de conta vs. cartão.
  - Transferências entre contas continuam corretas.
  - Provisionados continuam funcionando (não afetam limite/saldo até pagamento).

---

## 7. Notas de implementação já aplicadas

- `StatementService.markPaid` agora:
  - recebe `accountId` opcional;
  - cria a transação de pagamento de fatura com `date: DateTime.now()` e `accountId` preenchido;
  - mantém a lógica de remoção automática da transação se a fatura for desmarcada.
- `PaymentHubPage`:
  - antes de pagar uma fatura, abre um bottom sheet (`_AccountPickerSheet`) com as contas disponíveis;
  - repassa `accountId` para `PaymentHubService.markAsPaid`, que por sua vez chama `StatementService.markPaid`.

Próximos commits deste M6 devem referenciar este arquivo na descrição para manter o histórico rastreável.
