// Sessão de prévia e plano de gravação da importação. Contrato: docs/SPEC.md §5.16.

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/text_normalize.dart';
import '../../cards/domain/payment_card.dart';
import '../../transactions/domain/tags.dart';
import '../../transactions/domain/transaction.dart';
import 'categorizer.dart';
import 'import_installments.dart';
import 'import_matcher.dart';
import 'import_profile.dart';
import 'imported_line.dart';
import 'invoice_payment_match.dart';

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

/// Linha da prévia: linha lida + decisões (incluir, categoria, parcelas, fatura paga).
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
    this.invoicePayment,
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

  /// Fatura que este débito quita (SPEC §9.5); null = despesa comum.
  final InvoiceCandidate? invoicePayment;

  bool get isInvoicePayment => invoicePayment != null;
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
    Object? invoicePayment = _keep,
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
    invoicePayment: identical(invoicePayment, _keep)
        ? this.invoicePayment
        : invoicePayment as InvoiceCandidate?,
  );
}

/// Parcelas que a linha criaria por padrão (sem fatura, sem provisionado, sem parcela existente).
bool _createInstallmentsByDefault(
  InstallmentMark? installment,
  String description,
  ImportMatch match,
) =>
    installment != null &&
    installment.index < installment.count &&
    !isWeakInstallment(description) &&
    !match.flags.contains(ImportFlag.existingInstallment) &&
    match.plannedMatch == null;

/// Flags de duplicata: as únicas que impedem a sugestão de pagamento de fatura de vir marcada.
const Set<ImportFlag> _duplicateFlags = {
  ImportFlag.fitidDuplicate,
  ImportFlag.probableDuplicate,
};

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
  ImportSession._(
    List<ImportRow> rows, {
    required this.target,
    required List<InvoiceCandidate> invoiceCandidates,
  }) : rows = List.unmodifiable(rows),
       invoiceCandidates = List.unmodifiable(invoiceCandidates);

  /// Casa cada linha com o histórico (o `matcher` consome existentes na ordem das linhas).
  /// [invoiceCandidates] só tem efeito em destino conta (cartão → sem pagamento de fatura).
  factory ImportSession.build({
    required List<ImportedLine> lines,
    required ImportTarget target,
    PaymentCard? card,
    required Categorizer categorizer,
    required ImportMatcher matcher,
    Map<String, String> bankCategoryMap = const {},
    List<InvoiceCandidate> invoiceCandidates = const [],
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
      final invoice =
          target.accountId != null &&
              type == TransactionType.expense &&
              match.flags.contains(ImportFlag.invoicePaymentLike) &&
              match.plannedMatch == null
          ? suggestInvoicePayment(
              amountCents: line.amountCents.abs(),
              date: line.date,
              candidates: invoiceCandidates,
            )
          : null;
      rows.add(
        ImportRow(
          line: line,
          type: type,
          include: invoice == null
              ? !match.flags.any(_excludeByDefault.contains)
              : !match.flags.any(_duplicateFlags.contains),
          finalDescription: suggestion.renamedDescription ?? line.description,
          categoryId: invoice != null
              ? null
              : match.plannedMatch?.categoryId ?? suggestion.categoryId,
          suggestion: suggestion,
          categoryEdited: false,
          match: match,
          installment: installment,
          createInstallments:
              invoice == null &&
              _createInstallmentsByDefault(
                installment,
                line.description,
                match,
              ),
          invoicePayment: invoice,
        ),
      );
    }
    return ImportSession._(
      rows,
      target: target,
      invoiceCandidates: target.accountId != null
          ? invoiceCandidates
          : const [],
    );
  }

  /// Ordem do arquivo; imutável.
  final List<ImportRow> rows;

  /// Destino da importação; define se pagamento de fatura se aplica (só conta).
  final ImportTarget target;

  /// Faturas em aberto que a conta paga (vazio em importação de cartão).
  final List<InvoiceCandidate> invoiceCandidates;

  ImportSession _next(List<ImportRow> next) => ImportSession._(
    next,
    target: target,
    invoiceCandidates: invoiceCandidates,
  );

  ImportSession _replace(int i, ImportRow Function(ImportRow) change) =>
      _next([for (final (j, r) in rows.indexed) j == i ? change(r) : r]);

  ImportSession setInclude(int i, bool value) =>
      _replace(i, (r) => r.copyWith(include: value));

  ImportSession setAllIncluded(bool value) =>
      _next([for (final r in rows) r.copyWith(include: value)]);

  /// Marca `categoryEdited`. Linha de pagamento de fatura não tem categoria: ignora.
  ImportSession setCategory(int i, String? categoryId) => _replace(
    i,
    (r) => r.isInvoicePayment
        ? r
        : r.copyWith(categoryId: categoryId, categoryEdited: true),
  );

  /// Marca a débito como pagamento da fatura [c] (inclui a linha, sem categoria/parcelas);
  /// `null` desfaz e volta à despesa com a categoria sugerida. Ignorado em destino cartão e em receita.
  ImportSession setInvoicePayment(int i, InvoiceCandidate? c) {
    if (target.cardId != null) {
      return this;
    }
    return _replace(i, (r) {
      if (r.type != TransactionType.expense) {
        return r;
      }
      if (c != null) {
        return r.copyWith(
          invoicePayment: c,
          include: true,
          categoryId: null,
          createInstallments: false,
        );
      }
      return r.copyWith(
        invoicePayment: null,
        categoryId: r.categoryEdited
            ? r.categoryId
            : (r.match.plannedMatch?.categoryId ?? r.suggestion.categoryId),
        createInstallments: _createInstallmentsByDefault(
          r.installment,
          r.line.description,
          r.match,
        ),
      );
    });
  }

  /// Sem parcela na linha, não faz nada.
  ImportSession setCreateInstallments(int i, bool value) => _replace(
    i,
    (r) => r.installment == null ? r : r.copyWith(createInstallments: value),
  );

  /// Linhas não editadas recebem nova sugestão (categoria e descrição final).
  ImportSession recategorize(
    Categorizer categorizer, {
    Map<String, String> bankCategoryMap = const {},
  }) => _next([
    for (final r in rows)
      if (r.categoryEdited || r.isInvoicePayment)
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

  /// Índices (ordem do arquivo) das linhas sem categoria (pagamento de fatura não conta).
  List<int> uncategorizedIndices() => [
    for (final (i, r) in rows.indexed)
      if (r.categoryId == null && !r.isInvoicePayment) i,
  ];

  ({
    int create,
    int confirm,
    int skipped,
    int futureInstallments,
    int invoicePayments,
  })
  get summary {
    var create = 0;
    var confirm = 0;
    var skipped = 0;
    var future = 0;
    var invoices = 0;
    for (final r in rows) {
      if (!r.include) {
        skipped++;
        continue;
      }
      if (r.isInvoicePayment) {
        invoices++;
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
      invoicePayments: invoices,
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
    final invoice = r.invoicePayment;
    if (invoice != null) {
      // Pagamento de fatura: sem categoria, tags ou parcelas; não confirma provisionado.
      create.add(
        Transaction(
          id: idGenerator(),
          type: TransactionType.invoicePayment,
          amountCents: line.amountCents.abs(),
          date: line.date,
          description: r.finalDescription,
          accountId: target.accountId,
          cardId: invoice.cardId,
          invoiceKey: invoice.invoiceKey,
          status: TransactionStatus.paid,
          externalId: line.fitid,
          importedDescription: line.description,
        ),
      );
      continue;
    }
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
          tags: normalizeTags([...planned.tags, ...r.suggestion.tags]),
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
          tags: r.suggestion.tags,
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
          tags: r.suggestion.tags,
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
