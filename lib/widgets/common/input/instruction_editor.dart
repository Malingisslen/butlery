// lib/widgets/common/input/instruction_editor.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/styled/butlery_row_field.dart';

/// Dynamic instruction editor with Enter-key support for new steps
/// This widget provides a list of text fields that dynamically grows as users
/// add new instructions. Pressing Enter creates a new instruction field.
class InstructionEditor extends StatefulWidget {
  final List<String> initialInstructions;
  final ValueChanged<List<String>>? onChanged;

  const InstructionEditor({
    super.key,
    required this.initialInstructions,
    this.onChanged,
  });

  @override
  State<InstructionEditor> createState() => _InstructionEditorState();
}

class _InstructionEditorState extends State<InstructionEditor> {
  List<TextEditingController> controllers = [];

  @override
  void initState() {
    super.initState();
    controllers = widget.initialInstructions
        .map((text) => TextEditingController(text: text))
        .toList();
    if (controllers.isEmpty) {
      controllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleEnterPressed(int index, TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) return;

    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);

    if (mounted) {
      setState(() {
        controller.text = before;
        controller.selection = TextSelection.collapsed(offset: before.length);
        final newController = TextEditingController(text: after);
        controllers.insert(index + 1, newController);
      });
    }

    // Notify parent about changes
    _notifyChanges();
  }

  void _notifyChanges() {
    if (widget.onChanged != null) {
      final instructions = controllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      widget.onChanged!(instructions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(controllers.length, (i) {
        return ButleryFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The number stays when the hint gives way to the step's text.
            ButleryRowNumber(i + 1),
            Expanded(
              child: ButleryRowField(
                controller: controllers[i],
                hintText: context.l10n.instructionLabel(i + 1),
                style: AppTextStyles.bodyLarge,
                textCapitalization: TextCapitalization.sentences,
                onFieldSubmitted: (_) => _handleEnterPressed(i, controllers[i]),
                onChanged: (_) => _notifyChanges(),
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        );
      }),
    );
  }
}
