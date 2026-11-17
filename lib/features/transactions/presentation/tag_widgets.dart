import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/tags.dart';

/// Campo de tags: Enter ou `,`/`;` confirma; Backspace com campo vazio remove a última.
class TagField extends StatefulWidget {
  const TagField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.suggestions = const [],
    this.helperText,
    this.label = 'Tags',
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final String? helperText;
  final String label;

  @override
  State<TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<TagField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final added = parseTagInput(text);
    setState(_controller.clear);
    if (added.isNotEmpty) {
      widget.onChanged(normalizeTags([...widget.tags, ...added]));
    }
  }

  void _addSuggestion(String tag) {
    setState(_controller.clear);
    widget.onChanged(normalizeTags([...widget.tags, tag]));
  }

  @override
  Widget build(BuildContext context) {
    final typedKey = tagKey(_controller.text.trim());
    final current = {for (final t in widget.tags) tagKey(t)};
    final suggestions = [
      for (final s in widget.suggestions)
        if (!current.contains(tagKey(s)) && tagKey(s).startsWith(typedKey)) s,
    ].take(8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helperText,
          ),
          isEmpty: false,
          child: Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in widget.tags)
                InputChip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.chipBorder,
                  ),
                  onDeleted: () => widget.onChanged([
                    for (final t in widget.tags)
                      if (t != tag) t,
                  ]),
                ),
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      _controller.text.isEmpty &&
                      widget.tags.isNotEmpty) {
                    widget.onChanged(
                      widget.tags.sublist(0, widget.tags.length - 1),
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: SizedBox(
                  width: 140,
                  child: TextField(
                    key: const ValueKey('tag-input'),
                    controller: _controller,
                    decoration: null,
                    onChanged: (v) {
                      if (v.contains(',') || v.contains(';')) {
                        _commit(v);
                      } else {
                        setState(() {});
                      }
                    },
                    onSubmitted: _commit,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(s),
                  visualDensity: VisualDensity.compact,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.chipBorder,
                  ),
                  onPressed: () => _addSuggestion(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Chips `#tag` até [max]; o restante vira `+N`. Sem tags → nada.
class TagChips extends StatelessWidget {
  const TagChips({super.key, required this.tags, this.max = 3});

  final List<String> tags;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colors.textSecondary,
    );
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: colors.textSecondary.withValues(alpha: 0.08),
        borderRadius: AppRadius.chipBorder,
      ),
      child: Text(text, style: style),
    );
    final extra = tags.length - max;
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: [
        for (final tag in tags.take(max)) chip('#$tag'),
        if (extra > 0) chip('+$extra'),
      ],
    );
  }
}

/// Escolha do diálogo em massa: [remove] false = adicionar, true = remover.
typedef BulkTagsChoice = ({bool remove, List<String> tags});

/// Adiciona ou remove tags de [count] transações. Cancelar ou fechar → null.
Future<BulkTagsChoice?> showBulkTagsDialog(
  BuildContext context, {
  required int count,
  required List<String> suggestions,
}) {
  var remove = false;
  var tags = <String>[];
  var answered = false;
  return showDialog<BulkTagsChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) {
        // Duplo clique faria um segundo pop, fechando a rota de baixo.
        void close([BulkTagsChoice? value]) {
          if (!answered) {
            answered = true;
            Navigator.of(ctx).pop(value);
          }
        }

        return AlertDialog(
          title: Text('Tags em $count transações'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  key: const ValueKey('bulk-tags-mode'),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Adicionar')),
                    ButtonSegment(value: true, label: Text('Remover')),
                  ],
                  selected: {remove},
                  onSelectionChanged: (s) => setDialog(() => remove = s.first),
                ),
                const SizedBox(height: AppSpace.md),
                TagField(
                  tags: tags,
                  suggestions: suggestions,
                  onChanged: (v) => setDialog(() => tags = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => close(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: tags.isEmpty
                  ? null
                  : () => close((remove: remove, tags: tags)),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    ),
  );
}
