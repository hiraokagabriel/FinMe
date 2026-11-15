// Fluxo de importação: arquivo → assistente/diálogo → prévia → gravação. Contrato: docs/SPEC.md §5.16, §6.3 e §7.3 (Fase 8).

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../rules/domain/rule_suggestion.dart';
import '../../rules/presentation/rule_form.dart';
import '../domain/csv_import.dart';
import '../domain/import_matcher.dart';
import '../domain/import_profile.dart';
import '../domain/import_session.dart';
import '../domain/imported_line.dart';
import '../domain/ofx_parser.dart';
import 'import_mapping_dialog.dart';
import 'import_preview_page.dart';

/// Arquivo escolhido: nome (para OFX por extensão) e bytes crus.
typedef PickedImportFile = ({String name, List<int> bytes});

const _extractGroup = XTypeGroup(
  label: 'Extratos',
  extensions: ['csv', 'ofx', 'txt'],
);
final RegExp _ofxTagRe = RegExp('<ofx', caseSensitive: false);
const _readError = 'Não foi possível ler o arquivo.';

/// Trecho curto do erro para a SnackBar.
String _brief(Object e) {
  final s = e.toString();
  return s.length > 120 ? '${s.substring(0, 120)}…' : s;
}

/// Linha com o valor negado (OFX de fatura com compras positivas, `invertSign`).
ImportedLine _negated(ImportedLine l) => ImportedLine(
  row: l.row,
  date: l.date,
  description: l.description,
  amountCents: -l.amountCents,
  fitid: l.fitid,
  bankCategory: l.bankCategory,
);

/// OFX pela extensão ou pela tag `<OFX` (CSV com conteúdo OFX também conta).
bool looksLikeOfx(String fileName, String text) =>
    fileName.toLowerCase().endsWith('.ofx') || _ofxTagRe.hasMatch(text);

Future<PickedImportFile?> _pickFromDisk() async {
  final file = await openFile(acceptedTypeGroups: const [_extractGroup]);
  if (file == null) {
    return null;
  }
  return (name: file.name, bytes: await file.readAsBytes());
}

/// Perfil válido é reaplicado direto; senão abre o diálogo (CSV: mapeamento; OFX: destino).
Future<ImportSetup?> _setupFor(
  BuildContext context, {
  required ImportProfile? profile,
  required String text,
  required OfxStatement? statement,
}) {
  if (profile != null && profile.mappingError == null) {
    return Future.value((profile: profile, save: true));
  }
  if (statement != null) {
    return showImportTargetDialog(
      context,
      suggestCard: statement.isCreditCard,
      initial: profile,
    );
  }
  return showImportMappingDialog(context, text: text, initial: profile);
}

/// Importa um extrato. Perfil salvo é reaplicado sem assistente; sem perfil, abre o diálogo certo.
/// [pickFile] só para teste; sem ele usa o seletor de arquivo.
Future<void> startImport(
  BuildContext context, {
  ImportProfile? profile,
  Future<PickedImportFile?> Function()? pickFile,
}) async {
  final services = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  final PickedImportFile? picked;
  try {
    picked = await (pickFile ?? _pickFromDisk)();
  } catch (e) {
    snack('$_readError ${_brief(e)}');
    return;
  }
  if (picked == null || !context.mounted) {
    return;
  }

  final text = decodeText(picked.bytes);
  final ofx = looksLikeOfx(picked.name, text);
  if (profile != null && (profile.format == ImportFormat.ofx) != ofx) {
    snack(ofx ? 'O arquivo não é CSV' : 'O arquivo não é OFX');
    return;
  }

  // OFX é lido antes do diálogo: `isCreditCard` decide se o destino sugerido é cartão.
  OfxStatement? statement;
  if (ofx) {
    try {
      statement = parseOfx(text);
    } on FormatException {
      snack(_readError);
      return;
    }
  }

  final setup = await _setupFor(
    context,
    profile: profile,
    text: text,
    statement: statement,
  );
  if (setup == null || !context.mounted) {
    return;
  }

  final p = setup.profile;
  final ImportParseResult parsed;
  try {
    parsed =
        statement?.result ??
        parseCsvLines(readCsv(text, delimiter: p.delimiter), p);
  } catch (e) {
    snack('$_readError ${_brief(e)}');
    return;
  }
  // CSV já aplica invertSign no parser; OFX aplica aqui.
  final lines = statement != null && p.invertSign
      ? [for (final l in parsed.lines) _negated(l)]
      : parsed.lines;
  if (lines.isEmpty) {
    snack('Nenhuma linha válida no arquivo.');
    return;
  }

  final card = p.cardId == null ? null : services.cards.byId(p.cardId!);
  final target = ImportTarget(accountId: p.accountId, cardId: p.cardId);
  final session = ImportSession.build(
    lines: lines,
    target: target,
    card: card,
    categorizer: services.ledger.categorizer,
    matcher: ImportMatcher(services.transactions.all),
    bankCategoryMap: p.categoryMap,
  );

  final reviewed = await showImportPreview(
    context,
    session: session,
    sourceLabel: picked.name,
    errors: parsed.errors,
    bankCategoryMap: p.categoryMap,
    onCreateRule: (row) => showRuleForm(
      context,
      initialPattern: suggestRulePattern([row.line.description]),
      initialCategoryId: row.categoryId,
      sampleDescription: row.line.description,
    ),
  );
  if (reviewed == null || !context.mounted) {
    return;
  }

  final plan = buildImportPlan(
    reviewed,
    target: target,
    card: card,
    today: services.ledger.today,
    mode: p.installmentDateMode,
  );
  final rows = [...plan.create, ...plan.update];
  // Lançamentos primeiro: upsertAll grava antes de mexer na memória,
  // então falha não deixa item fantasma. Perfil depois: falha só perde o aprendizado.
  try {
    await services.transactions.upsertAll(rows);
  } catch (e) {
    snack('Não foi possível gravar a importação: ${_brief(e)}');
    return;
  }
  if (setup.save) {
    try {
      await services.importProfiles.upsert(
        p.learnBankCategories(learnedBankCategories(reviewed)),
      );
    } catch (_) {
      snack('Lançamentos importados, mas o perfil não foi salvo.');
      return;
    }
  }
  final confirmed = plan.update.isEmpty
      ? ''
      : ', ${plan.update.length} provisionados confirmados';
  snack('${plan.create.length} lançamentos importados$confirmed');
}
