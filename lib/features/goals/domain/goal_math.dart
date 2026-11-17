import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import 'goal.dart';

/// Reserva ativa por conta (metas arquivadas não entram). Contas com 0 são omitidas.
Map<String, int> reservedByAccount(Iterable<Goal> goals) {
  final totals = <String, int>{};
  for (final goal in goals) {
    final reserved = goal.reservedCents;
    if (goal.archived || reserved == 0) {
      continue;
    }
    totals.update(
      goal.accountId,
      (sum) => sum + reserved,
      ifAbsent: () => reserved,
    );
  }
  return totals;
}

/// Quanto ainda cabe reservar na conta: saldo menos reservas ativas, nunca negativo.
int availableToReserve({
  required String accountId,
  required int accountBalanceCents,
  required Iterable<Goal> goals,
}) {
  final free = accountBalanceCents - (reservedByAccount(goals)[accountId] ?? 0);
  return free < 0 ? 0 : free;
}

String? contributionError({
  required int amountCents,
  required int availableCents,
}) {
  if (amountCents <= 0) {
    return 'Informe um valor maior que zero';
  }
  if (amountCents > availableCents) {
    return 'Saldo livre na conta: ${formatMoney(availableCents)}';
  }
  return null;
}

String? withdrawalError({required int amountCents, required Goal goal}) {
  if (amountCents <= 0) {
    return 'Informe um valor maior que zero';
  }
  if (amountCents > goal.reservedCents) {
    return 'Reservado nesta meta: ${formatMoney(goal.reservedCents)}';
  }
  return null;
}

/// Bloqueia a remoção de um aporte se deixaria as retiradas acima do reservado.
String? removeMovementError(Goal goal, String movementId) {
  if (goal.withoutMovement(movementId).rawReservedCents < 0) {
    return 'Sem este aporte, as retiradas ficariam maiores que o reservado';
  }
  return null;
}

/// Parte da reserva sem saldo por trás (conta negativa ou menor que a reserva).
int overReservedCents({
  required int accountBalanceCents,
  required int reservedCents,
}) {
  final covered = accountBalanceCents < 0 ? 0 : accountBalanceCents;
  final over = reservedCents - covered;
  return over < 0 ? 0 : over;
}

/// Aporte mensal para atingir a meta até a data-alvo (arredonda para cima). Sem data → null.
int? monthlyContributionNeeded(Goal goal, DateTime today) {
  final target = goal.targetDate;
  if (target == null) {
    return null;
  }
  final remaining = goal.remainingCents;
  if (remaining == 0) {
    return 0;
  }
  var months = (target.year - today.year) * 12 + target.month - today.month;
  if (months < 1) {
    months = 1;
  }
  return (remaining + months - 1) ~/ months;
}

bool isGoalOverdue(Goal goal, DateTime today) {
  final target = goal.targetDate;
  return target != null && dateOnly(today).isAfter(target) && !goal.reached;
}
