import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/styled/field_error_line.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

/// The one-field name dialog behind creating a tag, creating a group and
/// renaming a group.
///
/// [submit] returns the failure to show, or null when it worked. A failure
/// stays in the dialog with the typed name kept, because a snackbar would sit
/// behind the dialog's scrim.
class PersonalTagNameDialog extends StatefulWidget {
  final String title;
  final String fieldLabel;
  final String? hint;
  final String initialName;
  final String confirmLabel;
  final String emptyMessage;
  final Future<String?> Function(String name) submit;

  const PersonalTagNameDialog({
    super.key,
    required this.title,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.emptyMessage,
    required this.submit,
    this.hint,
    this.initialName = '',
  });

  @override
  State<PersonalTagNameDialog> createState() => _PersonalTagNameDialogState();
}

class _PersonalTagNameDialogState extends State<PersonalTagNameDialog> {
  late final TextEditingController _controller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = widget.emptyMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await widget.submit(name);
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, name);
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledField(
              label: widget.fieldLabel,
              child: TextField(
                controller: _controller,
                style: fieldTextStyle(context, enabled: !_busy),
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: widget.hint),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _busy ? null : _confirm(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimensions.space8),
              Semantics(
                container: true,
                role: SemanticsRole.alert,
                child: FieldErrorLine(_error!),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        BusyButtonSemantics(
          busy: _busy,
          name: widget.confirmLabel,
          child: FilledButton(
            style: _busy
                ? PlateLineButton.busyStyle(
                    null,
                    Theme.of(context).filledButtonTheme.style,
                  )
                : null,
            onPressed: _busy ? PlateLineButton.ignore : _confirm,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
