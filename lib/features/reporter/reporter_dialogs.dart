// Small dialogs / sheets of the reporter flow.

import 'package:flutter/material.dart';

import 'reporter_language.dart';

/// Correct one misheard word. Empty text removes the word. Returns null when
/// cancelled.
Future<String?> showEditWordDialog(
  BuildContext context,
  Tr tr,
  String word,
) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: tr('Corectează cuvântul', 'Correct the word'),
      initial: word,
      hint: tr('Gol = șterge cuvântul', 'Empty = remove the word'),
      okLabel: tr('Salvează', 'Save'),
      cancelLabel: tr('Anulează', 'Cancel'),
      allowEmpty: true,
      multiline: false,
    ),
  );
}

/// Type the report instead of speaking it.
Future<String?> showTypeTextDialog(BuildContext context, Tr tr) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: tr('Scrie problema', 'Describe the problem'),
      initial: '',
      hint: tr(
          'Ex.: pată de combustibil la locul 3', 'E.g. fuel spill at stand 3'),
      okLabel: tr('Continuă', 'Continue'),
      cancelLabel: tr('Anulează', 'Cancel'),
      allowEmpty: false,
      multiline: true,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.okLabel,
    required this.cancelLabel,
    required this.allowEmpty,
    required this.multiline,
  });

  final String title;
  final String initial;
  final String hint;
  final String okLabel;
  final String cancelLabel;
  final bool allowEmpty;
  final bool multiline;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && !widget.allowEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: widget.multiline ? 4 : 1,
        textInputAction:
            widget.multiline ? TextInputAction.newline : TextInputAction.done,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: widget.multiline ? null : (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.okLabel)),
      ],
    );
  }
}

/// Optional place for a menu report ("Poarta 12"). Returns the text (maybe
/// empty) or null when dismissed.
Future<String?> showLocationSheet(
  BuildContext context,
  Tr tr,
  String typeLabel,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _LocationSheet(tr: tr, typeLabel: typeLabel),
  );
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({required this.tr, required this.typeLabel});

  final Tr tr;
  final String typeLabel;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.typeLabel, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: tr('Unde? (opțional)', 'Where? (optional)'),
              hintText:
                  tr('Ex.: Poarta 12, Sector 3', 'E.g. Gate 12, Sector 3'),
              prefixIcon: const Icon(Icons.place_outlined),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.send),
            label: Text(tr('Trimite raportul', 'Send report')),
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          ),
        ],
      ),
    );
  }
}
