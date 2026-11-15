// Sessão de prévia e plano de gravação da importação. Contrato: docs/SPEC.md §5.16.

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/text_normalize.dart';
import '../../cards/domain/payment_card.dart';
import '../../transactions/domain/transaction.dart';
import 'categorizer.dart';
import 'import_installments.dart';
import 'import_matcher.dart';
import 'import_profile.dart';
import 'imported_line.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o campo; `null` limpa; valor troca.
const Object _keep = Object();

/// Flags que deixam a linha desmarcada por padrão (o usuário decide).
const Set<ImportFlag> _excludeByDefault = {
  ImportFlag.fitidDuplicate,
  ImportFlag.probableDuplicate,
  ImportFlag.existingInstallment,
  ImportFlag.invoicePaymentLike,
};

/// Destino da importação: exatamente uma conta ou um cartão.
class ImportTarget {
  const ImportTarget({this.accountId, this.cardId})
    : assert(
        (accountId == null) != (cardId == null),
        'Informe exatamente uma conta ou um cartão',
      );

  final String? accountId;
  final String? cardId;
}

/// Linha da prévia: linha lida + decisões (incluir, categoria, parcelas).
class ImportRow {
  const ImportRow({
    required this.line,
    required this.type,
    required this.include,
    required this.finalDescription,
    required this.categoryId,
    required this.suggestion,
    required this.categoryEdited,
    required this.match,
    required this.installment,
    required this.createInstallments,
  });

  final ImportedLine line;

  /// expense (valor < 0) ou income.
  final TransactionType type;
  final bool include;

  /// `renameTo` da regra ou a descrição do arquivo.
  final String finalDescription;
  final String? categoryId;
  final CategorizationResult suggestion;

  /// O usuário escolheu a categoria; `recategorize` não a mexe.
  final bool categoryEdited;
  final ImportMatch match;
  final InstallmentMark? installment;
  final bool createInstallments;

  bool get confirmsPlanned => match.plannedMatch != null;
  bool get hasWarning => match.flags.isNotEmpty;

  /// Cria a série de parcelas futuras (linha nova, parcela não quitada).
  bool get makesSeries {
    final mark = installment;
    return createInstallments &&
        !confirmsPlanned &&
        mark != null &&
        mark.index < mark.count;
  }

  ImportRow copyWith({
    bool? include,
    Object? categoryId = _keep,
    bool? categoryEdited,
    bool? createInstallments,
    String? finalDescription,
    CategorizationResult? suggestion,
  }) => ImportRow(
    line: line,
    type: type,
    include: include ?? this.include,
    finalDescription: finalDescription ?? this.finalDescription,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    suggestion: suggestion ?? this.suggestion,
    categoryEdited: categoryEdited ?? this.categoryEdited,
    match: match,
    installment: installment,
    createInstallments: createInstallments ?? this.createInstallments,
  );
}

CategorizationResult _suggest(
  ImportedLine line,
  TransactionType type,
  Categorizer categorizer,
  Map<String, String> bankCategoryMap,
) => categorizer.categorize(
  line.description,
  isIncome: type == TransactionType.income,
  bankCategory: line.bankCategory,
  bankCategoryMap: bankCategoryMap,
);

/// Sessão imutável: cada alteração devolve uma nova sessão.
class ImportSession {
  ImportSession._(List<ImportRow> rows) : rows = List.unmodifiable(rows);

  /// Casa cada linha com o histórico (o `matcher` consome existentes na ordem das linhas).
  factory ImportSession.build({
    required List<ImportedLine> lines,
    required ImportTarget target,
    PaymentCard? card,
    required Categorizer categorizer,
    required ImportMatcher matcher,
    Map<String, String> bankCategoryMap = const {},
  }) {
    final rows = <ImportRow>[];
    for (final line in lines) {
      final type = line.amountCents < 0
          ? TransactionType.expense
          : TransactionType.income;
      final installment = detectInstallment(line.description, date: line.date);
      final match = matcher.match(
        line,
        accountId: target.accountId,
        cardId: target.cardId,
        installment: installment,
      );
      final suggestion = _suggest(line, type, categorizer, bankCategoryMap);
      rows.add(
        ImportRow(
          line: line,
          type: type,
          include: !match.flags.any(_excludeByDefault.contains),
          finalDescription: suggestion.renamedDescription ?? line.description,
          categoryId: match.plannedMatch?.categoryId ?? suggestion.categoryId,
          suggestion: suggestion,
          categoryEdited: false,
          match: match,
          installment: installment,
          createInstallments:
              installment != null &&
              installment.index < installment.count &&
              !isWeakInstallment(line.description) &&
              !match.flags.contains(ImportFlag.existingInstallment) &&
              match.plannedMatch == null,
        ),
      );
    }
    return ImportSession._(rows);
  }

  /// Ordem do arquivo; imutável.
  final List<ImportRow> rows;

  ImportSession _replace(int i, ImportRow Function(ImportRow) change) =>
      ImportSession._([
        for (final (j, r) in rows.indexed) j == i ? change(r) : r,
      ]);

  ImportSession setInclude(int i, bool value) =>
      _replace(i, (r) => r.copyWith(include: value));

  ImportSession setAllIncluded(bool value) =>
      ImportSession._([for (final r in rows) r.copyWith(include: value)]);

  /// Marca `categoryEdited`.
  ImportSession setCategory(int i, String? categoryId) => _replace(
    i,
    (r) => r.copyWith(categoryId: categoryId, categoryEdited: true),
  );

  /// Sem parcela na linha, não faz nada.
  ImportSession setCreateInstallments(int i, bool value) => _replace(
    i,
    (r) => r.installment == null ? r : r.copyWith(createInstallments: value),
  );

  /// Linhas não editadas recebem nova sugestão (categoria e descrição final).
  ImportSession recategorize(
    Categorizer categorizer, {
    Map<String, String> bankCategoryMap = const {},
  }) => ImportSession._([
    for (final r in rows)
      if (r.categoryEdited)
        r
      else
        _recategorized(r, categorizer, bankCategoryMap),
  ]);

  ImportRow _recategorized(
    ImportRow r,
    Categorizer categorizer,
    Map<String, String> bankCategoryMap,
  ) {
    final s = _suggest(r.line, r.type, categorizer, bankCategoryMap);
    return r.copyWith(
      suggestion: s,
      finalDescription: s.renamedDescription ?? r.line.description,
      categoryId: r.match.plannedMatch?.categoryId ?? s.categoryId,
    );
  }

  /// Índices (ordem do arquivo) das linhas sem categoria.
  List<int> uncategorizedIndices() => [
    for (final (i, r) in rows.indexed)
      if (r.categoryId == null) i,
  ];

  ({int create, int confirm, int skipped, int futureInstallments}) get summary {
    var create = 0;
    var confirm = 0;
    var skipped = 0;
    var future = 0;
    for (final r in rows) {
      if (!r.include) {
        skipped++;
        continue;
      }
      if (r.confirmsPlanned) {
        confirm++;
      } else {
        create++;
      }
      if (r.makesSeries) {
        future += r.installment!.count - r.installment!.index;
      }
    }
    return (
      create: create,
      confirm: confirm,
      skipped: skipped,
      futureInstallments: future,
    );
  }
}

/// Transações a criar e a atualizar (provisionados confirmados).
class ImportPlan {
  const ImportPlan({required this.create, required this.update});

  final List<Transaction> create;
  final List<Transaction> update;
}

/// Só linhas incluídas geram transações. [idGenerator] é injetável (testes usam ids fixos).
ImportPlan buildImportPlan(
  ImportSession session, {
  required ImportTarget target,
  PaymentCard? card,
  required DateTime today,
  InstallmentDateMode mode = InstallmentDateMode.posting,
  String Function() idGenerator = newId,
}) {
  final create = <Transaction>[];
  final update = <Transaction>[];
  final todayOnly = dateOnly(today);
  for (final r in session.rows) {
    if (!r.include) {
      continue;
    }
    final line = r.line;
    final planned = r.match.plannedMatch;
    if (planned != null) {
      update.add(
        planned.copyWith(
          status: TransactionStatus.paid,
          date: line.date,
          externalId: line.fitid ?? planned.externalId,
          importedDescription: line.description,
          categoryId: r.categoryEdited
              ? r.categoryId
              : (planned.categoryId ?? r.categoryId),
        ),
      );
      continue;
    }
    final status = line.date.isAfter(todayOnly)
        ? TransactionStatus.planned
        : TransactionStatus.paid;
    final amount = line.amountCents.abs();
    final mark = r.installment;
    if (!r.makesSeries || mark == null) {
      create.add(
        Transaction(
          id: idGenerator(),
          type: r.type,
          amountCents: amount,
          date: line.date,
          description: r.finalDescription,
          categoryId: r.categoryId,
          accountId: target.accountId,
          cardId: target.cardId,
          status: status,
          externalId: line.fitid,
          importedDescription: line.description,
        ),
      );
      continue;
    }
    final groupId = idGenerator();
    final dates = importedInstallmentDates(
      lineDate: line.date,
      index: mark.index,
      count: mark.count,
      mode: mode,
      card: card,
    );
    for (final p in dates) {
      final i = p.index;
      final isImported = i == mark.index;
      create.add(
        Transaction(
          id: '${groupId}_$i',
          type: r.type,
          amountCents: amount,
          date: p.date,
          description: r.finalDescription,
          categoryId: r.categoryId,
          accountId: target.accountId,
          cardId: target.cardId,
          status: isImported ? status : TransactionStatus.planned,
          installmentGroupId: groupId,
          installmentIndex: i,
          installmentCount: mark.count,
          externalId: isImported ? line.fitid : null,
          importedDescription: isImported ? line.description : null,
        ),
      );
    }
  }
  return ImportPlan(create: create, update: update);
}

/// Aprende `bankCategory` → categoria das linhas incluídas (última vence). Chave: `foldText`.
Map<String, String> learnedBankCategories(ImportSession session) {
  final learned = <String, String>{};
  for (final r in session.rows) {
    final bank = r.line.bankCategory;
    final categoryId = r.categoryId;
    if (!r.include || bank == null || categoryId == null) {
      continue;
    }
    final key = foldText(bank);
    if (key.isNotEmpty) {
      learned[key] = categoryId;
    }
  }
  return learned;
}
