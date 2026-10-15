import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/styled/field_error_line.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

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
    return ButleryDialog(
      title: widget.title,
      scrollable: false,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StyledInput(
              label: widget.fieldLabel,
              hint: widget.hint,
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _busy ? null : _confirm(),
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
        DialogCancelButton(enabled: !_busy),
        ButleryDialogPrimary(
          label: widget.confirmLabel,
          busy: _busy,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
