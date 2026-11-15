import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/csv_import.dart';
import '../domain/import_profile.dart';
import '../domain/imported_line.dart';

/// Resultado do assistente: perfil montado e se ele deve ser salvo.
typedef ImportSetup = ({ImportProfile profile, bool save});

const _sampleRows = 8;
const _sampleColumnWidth = 140.0;
const _fieldWidth = 240.0;
// shortcut: sem amostra (edição de perfil sem arquivo) o seletor tem 10 colunas; upgrade: deixar digitar o índice.
const _emptyColumnCount = 10;

const _delimiterLabels = {
  ';': 'Ponto e vírgula (;)',
  ',': 'Vírgula (,)',
  '\t': 'Tabulação',
  '|': 'Barra vertical (|)',
};
const _dateOrderLabels = {
  DateOrder.dmy: 'dd/mm/aaaa',
  DateOrder.mdy: 'mm/dd/aaaa',
  DateOrder.ymd: 'aaaa-mm-dd',
};
const _decimalLabels = {
  DecimalMark.comma: 'Vírgula (1.234,56)',
  DecimalMark.dot: 'Ponto (1,234.56)',
};
const _amountModeLabels = {false: 'Valor único', true: 'Débito e crédito'};
const _installmentLabels = {
  InstallmentDateMode.posting: 'Lançamento na fatura',
  InstallmentDateMode.purchase: 'Compra original',
};

/// Assistente de mapeamento CSV. `text` vazio = editar perfil sem amostra. Cancelar → null.
Future<ImportSetup?> showImportMappingDialog(
  BuildContext context, {
  required String text,
  ImportProfile? initial,
}) => showDialog<ImportSetup>(
  context: context,
  builder: (_) => _MappingDialog(
    services: AppScope.of(context),
    text: text,
    initial: initial,
  ),
);

/// Destino de extrato OFX (conta ou cartão ativo), inverter sinal e salvar perfil. Cancelar → null.
Future<ImportSetup?> showImportTargetDialog(
  BuildContext context, {
  required bool suggestCard,
  ImportProfile? initial,
}) => showDialog<ImportSetup>(
  context: context,
  builder: (_) => _TargetDialog(
    services: AppScope.of(context),
    suggestCard: suggestCard,
    initial: initial,
  ),
);

// Destino é uma chave 'a:<id>' (conta) ou 'c:<id>' (cartão) no DropdownButtonFormField.

List<DropdownMenuItem<String>> _targetItems(AppServices s) => [
  for (final a in s.accounts.all)
    if (!a.archived)
      DropdownMenuItem(value: 'a:${a.id}', child: Text('Conta · ${a.name}')),
  for (final c in s.cards.all)
    if (!c.archived)
      DropdownMenuItem(value: 'c:${c.id}', child: Text('Cartão · ${c.name}')),
];

String? _keyOf(ImportProfile p) => p.accountId != null
    ? 'a:${p.accountId}'
    : p.cardId != null
    ? 'c:${p.cardId}'
    : null;

/// Perfil existente: o destino dele, se ainda ativo. Perfil novo: 1ª conta (ou cartão se `preferCard`).
String? _initialTarget(
  ImportProfile? initial,
  List<DropdownMenuItem<String>> items, {
  bool preferCard = false,
}) {
  if (initial != null) {
    final key = _keyOf(initial);
    return items.any((i) => i.value == key) ? key : null;
  }
  final keys = [for (final i in items) i.value!];
  final accounts = keys.where((k) => k.startsWith('a:'));
  final cards = keys.where((k) => k.startsWith('c:'));
  final ordered = preferCard
      ? [...cards, ...accounts]
      : [...accounts, ...cards];
  return ordered.isEmpty ? null : ordered.first;
}

ImportProfile _withTarget(ImportProfile p, String? key) {
  final id = key?.substring(2);
  final isCard = key?.startsWith('c:') ?? false;
  return p.copyWith(accountId: isCard ? null : id, cardId: isCard ? id : null);
}

bool _canSubmit(ImportProfile p, bool save, String name) =>
    p.mappingError == null && (!save || name.trim().isNotEmpty);

List<Widget> _dialogActions(
  BuildContext context, {
  required bool canSubmit,
  required VoidCallback onSubmit,
}) => [
  TextButton(
    onPressed: () => Navigator.of(context).pop(),
    child: const Text('Cancelar'),
  ),
  FilledButton(
    onPressed: canSubmit ? onSubmit : null,
    child: const Text('Continuar'),
  ),
];

class _MappingDialog extends StatefulWidget {
  const _MappingDialog({
    required this.services,
    required this.text,
    this.initial,
  });

  final AppServices services;
  final String text;
  final ImportProfile? initial;

  @override
  State<_MappingDialog> createState() => _MappingDialogState();
}

class _MappingDialogState extends State<_MappingDialog> {
  late final List<DropdownMenuItem<String>> _targets = _targetItems(
    widget.services,
  );
  late final TextEditingController _name;
  late final TextEditingController _skip;
  late bool _save;
  late ImportProfile _p;
  late List<List<String>> _rows;
  late int _width;
  ImportParseResult? _preview;

  @override
  void initState() {
    super.initState();
    final base =
        widget.initial ??
        ImportProfile(
          id: newId(),
          name: '',
          delimiter: guessDelimiter(widget.text),
        );
    _save = widget.initial != null;
    _name = TextEditingController(text: base.name);
    _skip = TextEditingController(text: '${base.skipRows}');
    _p = _withTarget(base, _initialTarget(widget.initial, _targets));
    _loadRows(_p.delimiter);
    _preview = _computePreview();
  }

  @override
  void dispose() {
    _name.dispose();
    _skip.dispose();
    super.dispose();
  }

  void _loadRows(String delimiter) {
    _rows = readCsv(widget.text, delimiter: delimiter);
    _width = _rows.fold(0, (m, r) => max(m, r.length));
  }

  /// Só interpreta quando o mapeamento está válido; sem amostra não há prévia.
  ImportParseResult? _computePreview() =>
      _p.mappingError != null || _rows.isEmpty
      ? null
      : parseCsvLines(_rows, _p);

  void _update(ImportProfile next) => setState(() {
    _p = next;
    _preview = _computePreview();
  });

  void _setDelimiter(String delimiter) => setState(() {
    _loadRows(delimiter);
    _p = _p.copyWith(delimiter: delimiter);
    _preview = _computePreview();
  });

  void _setPairMode(bool pair) => _update(
    pair
        ? _p.copyWith(
            amountColumn: null,
            debitColumn: _p.debitColumn ?? _p.amountColumn ?? 2,
            creditColumn: _p.creditColumn ?? 3,
          )
        : _p.copyWith(
            amountColumn: _p.debitColumn ?? 2,
            debitColumn: null,
            creditColumn: null,
          ),
  );

  void _submit() => Navigator.of(context).pop<ImportSetup>((
    profile: _p.copyWith(name: _name.text.trim()),
    save: _save,
  ));

  int get _columnCount {
    final used = [
      _p.dateColumn,
      _p.descriptionColumn,
      _p.amountColumn,
      _p.debitColumn,
      _p.creditColumn,
      _p.categoryColumn,
    ].whereType<int>();
    final highest = used.fold(-1, (m, c) => max(m, c));
    return max(_rows.isEmpty ? _emptyColumnCount : _width, highest + 1);
  }

  List<String> get _headerRow => _p.skipRows >= 1 && _p.skipRows <= _rows.length
      ? _rows[_p.skipRows - 1]
      : const [];

  String _columnLabel(int i) {
    final header = _headerRow;
    final name = i < header.length ? header[i] : '';
    return name.isEmpty ? 'Col ${i + 1}' : 'Col ${i + 1} — $name';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Mapear colunas do CSV'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_rows.isNotEmpty) ...[
              Text('Amostra', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpace.sm),
              _sample(context),
              const SizedBox(height: AppSpace.lg),
            ],
            _mappingFields(),
            const SizedBox(height: AppSpace.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Inverter sinal'),
              subtitle: const Text(
                'Use quando as compras da fatura vêm positivas',
              ),
              value: _p.invertSign,
              onChanged: (v) => _update(_p.copyWith(invertSign: v ?? false)),
            ),
            const SizedBox(height: AppSpace.md),
            _previewSection(context),
            const SizedBox(height: AppSpace.md),
            _SaveAsProfile(
              save: _save,
              name: _name,
              onSaveChanged: (v) => setState(() => _save = v),
              onNameChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        canSubmit: _canSubmit(_p, _save, _name.text),
        onSubmit: _submit,
      ),
    );
  }

  Widget _sample(BuildContext context) {
    final c = context.colors;
    final base = Theme.of(context).textTheme.bodyMedium!;
    final headerIndex = _p.skipRows - 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: AppRadius.cardBorder,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < min(_sampleRows, _rows.length); r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _width; i++)
                    SizedBox(
                      width: _sampleColumnWidth,
                      child: Text(
                        i < _rows[r].length ? _rows[r][i] : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: base.copyWith(
                          color: r < headerIndex
                              ? c.textSecondary
                              : c.textPrimary,
                          fontWeight: r == headerIndex
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _mappingFields() {
    final p = _p;
    final pair = p.amountColumn == null;
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.md,
      children: [
        _boxed(
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: p.delimiter,
            decoration: const InputDecoration(labelText: 'Separador'),
            items: [
              for (final d in {..._delimiterLabels.keys, p.delimiter})
                DropdownMenuItem(
                  value: d,
                  child: Text(_delimiterLabels[d] ?? d),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                _setDelimiter(v);
              }
            },
          ),
        ),
        _boxed(
          TextField(
            controller: _skip,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Linhas a pular'),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) {
                _update(_p.copyWith(skipRows: n));
              }
            },
          ),
        ),
        // SegmentedButton quebra dentro do IntrinsicWidth do AlertDialog: usa dropdown.
        _enumField('Tipo de valor', pair, _amountModeLabels, _setPairMode),
        _columnField(
          'Data',
          p.dateColumn,
          (v) => _update(_p.copyWith(dateColumn: v)),
        ),
        _columnField(
          'Descrição',
          p.descriptionColumn,
          (v) => _update(_p.copyWith(descriptionColumn: v)),
        ),
        if (pair) ...[
          _columnField(
            'Débito',
            p.debitColumn,
            (v) => _update(_p.copyWith(debitColumn: v)),
            optional: true,
          ),
          _columnField(
            'Crédito',
            p.creditColumn,
            (v) => _update(_p.copyWith(creditColumn: v)),
            optional: true,
          ),
        ] else
          _columnField(
            'Valor',
            p.amountColumn,
            (v) => _update(_p.copyWith(amountColumn: v)),
          ),
        _columnField(
          'Categoria',
          p.categoryColumn,
          (v) => _update(_p.copyWith(categoryColumn: v)),
          optional: true,
        ),
        _enumField(
          'Formato da data',
          p.dateOrder,
          _dateOrderLabels,
          (v) => _update(_p.copyWith(dateOrder: v)),
        ),
        _enumField(
          'Decimal',
          p.decimalMark,
          _decimalLabels,
          (v) => _update(_p.copyWith(decimalMark: v)),
        ),
        _enumField(
          'Data das parcelas',
          p.installmentDateMode,
          _installmentLabels,
          (v) => _update(_p.copyWith(installmentDateMode: v)),
        ),
        _boxed(
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _keyOf(p),
            decoration: const InputDecoration(labelText: 'Destino'),
            items: _targets,
            onChanged: (v) => _update(_withTarget(_p, v)),
          ),
        ),
      ],
    );
  }

  /// Prévia (5 linhas interpretadas) ou o erro de mapeamento no lugar dela.
  Widget _previewSection(BuildContext context) {
    final c = context.colors;
    final base = Theme.of(context).textTheme.bodyMedium!;
    final error = _p.mappingError;
    if (error != null) {
      return Text(error, style: base.copyWith(color: c.danger));
    }
    final r = _preview;
    if (r == null) {
      return const SizedBox.shrink();
    }
    final firstError = r.errors.isEmpty ? null : r.errors.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prévia: ${r.lines.length} linhas interpretadas, '
          '${r.errors.length} com erro',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (final line in r.lines.take(5)) _previewRow(line),
        if (firstError != null)
          Text(
            'Linha ${firstError.row}: ${firstError.message}',
            style: base.copyWith(color: c.warning),
          ),
      ],
    );
  }

  Widget _previewRow(ImportedLine line) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
    child: Row(
      children: [
        SizedBox(width: 88, child: Text(formatDate(line.date))),
        Expanded(
          child: Text(
            line.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        MoneyText(line.amountCents, signed: true, colorBySign: true),
      ],
    ),
  );

  Widget _columnField(
    String label,
    int? value,
    ValueChanged<int?> onChanged, {
    bool optional = false,
  }) => _boxed(
    DropdownButtonFormField<int?>(
      isExpanded: true,
      key: ValueKey(label),
      // Índice negativo (perfil inválido) não existe nas opções: mostra vazio.
      initialValue: value != null && value < 0 ? null : value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (optional)
          const DropdownMenuItem<int?>(value: null, child: Text('Nenhuma')),
        for (var i = 0; i < _columnCount; i++)
          DropdownMenuItem<int?>(value: i, child: Text(_columnLabel(i))),
      ],
      onChanged: onChanged,
    ),
  );

  Widget _enumField<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) => _boxed(
    DropdownButtonFormField<T>(
      isExpanded: true,
      key: ValueKey(label),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
        }
      },
    ),
  );
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({
    required this.services,
    required this.suggestCard,
    this.initial,
  });

  final AppServices services;
  final bool suggestCard;
  final ImportProfile? initial;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final List<DropdownMenuItem<String>> _targets = _targetItems(
    widget.services,
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late bool _save = widget.initial != null;
  late ImportProfile _p = _withTarget(
    widget.initial ??
        ImportProfile(id: newId(), name: '', format: ImportFormat.ofx),
    _initialTarget(widget.initial, _targets, preferCard: widget.suggestCard),
  ).copyWith(format: ImportFormat.ofx);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop<ImportSetup>((
    profile: _p.copyWith(name: _name.text.trim()),
    save: _save,
  ));

  @override
  Widget build(BuildContext context) {
    final error = _p.mappingError;
    return AlertDialog(
      scrollable: true,
      title: const Text('Destino do extrato OFX'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _keyOf(_p),
              decoration: const InputDecoration(labelText: 'Destino'),
              items: _targets,
              onChanged: (v) => setState(() => _p = _withTarget(_p, v)),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Text(
                  error,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.danger,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Inverter sinal'),
              value: _p.invertSign,
              onChanged: (v) =>
                  setState(() => _p = _p.copyWith(invertSign: v ?? false)),
            ),
            _SaveAsProfile(
              save: _save,
              name: _name,
              onSaveChanged: (v) => setState(() => _save = v),
              onNameChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        canSubmit: _canSubmit(_p, _save, _name.text),
        onSubmit: _submit,
      ),
    );
  }
}

/// "Salvar como perfil" + nome; o nome só é editável com a opção marcada.
class _SaveAsProfile extends StatelessWidget {
  const _SaveAsProfile({
    required this.save,
    required this.name,
    required this.onSaveChanged,
    required this.onNameChanged,
  });

  final bool save;
  final TextEditingController name;
  final ValueChanged<bool> onSaveChanged;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: save,
          title: const Text('Salvar como perfil'),
          onChanged: (v) => onSaveChanged(v ?? false),
        ),
        TextField(
          controller: name,
          enabled: save,
          decoration: const InputDecoration(labelText: 'Nome do perfil'),
          onChanged: (_) => onNameChanged(),
        ),
      ],
    );
  }
}

Widget _boxed(Widget child) => SizedBox(width: _fieldWidth, child: child);
