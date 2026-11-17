import '../../../core/utils/text_normalize.dart';
import '../../transactions/domain/transaction.dart';
import 'imported_line.dart';

enum ImportFlag {
  fitidDuplicate,
  probableDuplicate,
  existingInstallment,
  sameNameAmount,
  invoicePaymentLike,
}

/// Resultado do casamento de uma linha importada com o histórico.
class ImportMatch {
  const ImportMatch({
    this.flags = const {},
    this.duplicateOf,
    this.plannedMatch,
  });

  final Set<ImportFlag> flags;

  /// Existente que motivou fitid/probable/existingInstallment.
  final Transaction? duplicateOf;

  /// Provisionado a confirmar.
  final Transaction? plannedMatch;
}

/// Sinal de pagamento de fatura no extrato; casa com `foldText(description)`.
final RegExp kInvoicePaymentPattern = RegExp(
  r'\b(PAG(TO|AMENTO)?|PGTO)\s+(DE\s+)?(FATURA|CARTAO)\b|\bPAGAMENTO\s+(RECEBIDO|EFETUADO)\b',
);

/// Assunto da transação para casamento; igual a `ruleSubject` de rules/ (sem importar rules/).
String _subject(Transaction t) => t.importedDescription ?? t.description;

String _origem(String? accountId, String? cardId) =>
    '${accountId ?? ''}|${cardId ?? ''}';

int _dayDiff(DateTime a, DateTime b) => DateTime.utc(
  a.year,
  a.month,
  a.day,
).difference(DateTime.utc(b.year, b.month, b.day)).inDays.abs();

/// Casa linhas importadas com o histórico. **Com estado**: cada existente casa no máximo uma linha
/// (ids consumidos), na ordem das chamadas a [match].
class ImportMatcher {
  ImportMatcher(Iterable<Transaction> existing) {
    for (final t in existing) {
      if (t.type != TransactionType.expense &&
          t.type != TransactionType.income) {
        continue;
      }
      final origem = _origem(t.accountId, t.cardId);
      final valor = t.amountCents;
      if (t.externalId != null) {
        _byFitid.putIfAbsent('$origem|${t.externalId}', () => []).add(t);
      }
      _byBucket.putIfAbsent('$origem|${t.type.name}|$valor', () => []).add(t);
      if (t.installmentIndex != null && t.installmentCount != null) {
        _byInstallment
            .putIfAbsent(
              '$origem|${t.installmentIndex}/${t.installmentCount}|$valor',
              () => [],
            )
            .add(t);
      }
      final name = '${normalizeDescription(_subject(t))}|$valor';
      _nameCount[name] = (_nameCount[name] ?? 0) + 1;
    }
  }

  final Map<String, List<Transaction>> _byFitid = {};
  final Map<String, List<Transaction>> _byBucket = {};
  final Map<String, List<Transaction>> _byInstallment = {};
  final Map<String, int> _nameCount = {};
  final Set<String> _consumed = {};

  ImportMatch match(
    ImportedLine line, {
    String? accountId,
    String? cardId,
    ({int index, int count})? installment,
  }) {
    final origem = _origem(accountId, cardId);
    final tipo = line.amountCents < 0
        ? TransactionType.expense
        : TransactionType.income;
    final valor = line.amountCents.abs();
    final core = _matchCore(line, origem, tipo, valor, installment);

    final flags = {...core.flags};
    final norm = normalizeDescription(line.description);
    // Sem flag de núcleo e sem provisionado a confirmar (passo 4 e parcela provisionada não geram flag).
    if (core.flags.isEmpty &&
        core.plannedMatch == null &&
        norm.isNotEmpty &&
        (_nameCount['$norm|$valor'] ?? 0) > 0) {
      flags.add(ImportFlag.sameNameAmount);
    }
    if (kInvoicePaymentPattern.hasMatch(foldText(line.description))) {
      flags.add(ImportFlag.invoicePaymentLike);
    }
    return ImportMatch(
      flags: flags,
      duplicateOf: core.duplicateOf,
      plannedMatch: core.plannedMatch,
    );
  }

  /// Precedência 1–4; a primeira que casar define o resultado e consome a existente.
  ImportMatch _matchCore(
    ImportedLine line,
    String origem,
    TransactionType tipo,
    int valor,
    ({int index, int count})? installment,
  ) {
    final bucket = _byBucket['$origem|${tipo.name}|$valor'];

    // 1. FITID.
    if (line.fitid != null) {
      final t = _pick(_byFitid['$origem|${line.fitid}'], line.date);
      if (t != null) {
        return _consume(t, ImportFlag.fitidDuplicate);
      }
    }

    // 2. Parcela existente com mesmo índice/total e descrição parecida. Provisionada → confirma.
    if (installment != null) {
      final t = _pick(
        _byInstallment['$origem|${installment.index}/${installment.count}|$valor'],
        line.date,
        accept: (t) => similarDescriptions(line.description, _subject(t)),
      );
      if (t != null && t.status == TransactionStatus.planned) {
        _consumed.add(t.id);
        return ImportMatch(plannedMatch: t);
      }
      if (t != null) {
        return _consume(t, ImportFlag.existingInstallment);
      }
    }

    // 3. Paga, até 1 dia, descrição parecida.
    final probable = _pick(
      bucket,
      line.date,
      status: TransactionStatus.paid,
      maxDays: 1,
      accept: (t) => similarDescriptions(line.description, _subject(t)),
    );
    if (probable != null) {
      return _consume(probable, ImportFlag.probableDuplicate);
    }

    // 4. Provisionado até 5 dias; descrição não importa (boleto costuma vir diferente).
    // Parcela de série só casa com linha que também é parcela (compra avulsa não a consome).
    final planned = _pick(
      bucket,
      line.date,
      status: TransactionStatus.planned,
      maxDays: 5,
      accept: (t) => installment != null || t.installmentGroupId == null,
    );
    if (planned != null) {
      _consumed.add(planned.id);
      return ImportMatch(plannedMatch: planned);
    }
    return const ImportMatch();
  }

  ImportMatch _consume(Transaction t, ImportFlag flag) {
    _consumed.add(t.id);
    return ImportMatch(flags: {flag}, duplicateOf: t);
  }

  /// Menor distância de data (empate: menor id) entre as não consumidas que passam nos filtros.
  Transaction? _pick(
    List<Transaction>? bucket,
    DateTime date, {
    TransactionStatus? status,
    int? maxDays,
    bool Function(Transaction t)? accept,
  }) {
    Transaction? best;
    var bestDist = 0;
    for (final t in bucket ?? const <Transaction>[]) {
      if (_consumed.contains(t.id)) {
        continue;
      }
      if (status != null && t.status != status) {
        continue;
      }
      final dist = _dayDiff(t.date, date);
      if (maxDays != null && dist > maxDays) {
        continue;
      }
      if (accept != null && !accept(t)) {
        continue;
      }
      if (best == null ||
          dist < bestDist ||
          (dist == bestDist && t.id.compareTo(best.id) < 0)) {
        best = t;
        bestDist = dist;
      }
    }
    return best;
  }
}
