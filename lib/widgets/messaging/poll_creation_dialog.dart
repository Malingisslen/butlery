// lib/widgets/messaging/poll_creation_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Dialog for creating a new poll in a chat conversation.
/// Supports 2-4 options, single/multiple choice toggle, and optional deadline.
class PollCreationDialog extends StatefulWidget {
  final String creatorId;

  const PollCreationDialog({super.key, required this.creatorId});

  @override
  State<PollCreationDialog> createState() => _PollCreationDialogState();
}

class _PollCreationDialogState extends State<PollCreationDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultiple = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    final filledOptions =
        _optionControllers.where((c) => c.text.trim().isNotEmpty).length;
    return filledOptions >= 2;
  }

  void _addOption() {
    if (_optionControllers.length >= 4) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _submit() {
    if (!_isValid) return;
    final optionTexts = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final poll = Poll.create(
      question: _questionController.text.trim(),
      optionTexts: optionTexts,
      creatorId: widget.creatorId,
      allowMultipleChoices: _allowMultiple,
    );

    Navigator.of(context).pop(poll);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.all(Radius.circular(AppDimensions.borderRadiusS)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Skapa omröstning',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingMd),

              // Question field
              TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  labelText: 'Fråga',
                  hintText: 'Vad vill du fråga?',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppDimensions.borderRadiusS)),
                  ),
                  labelStyle: AppTextStyles.labelMedium
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                onChanged: (_) => setState(() {}),
                maxLines: 2,
              ),
              const SizedBox(height: AppDimensions.spacingMd),

              // Option fields
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppDimensions.spacingSm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Alternativ ${index + 1}',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                  Radius.circular(AppDimensions.borderRadiusS)),
                            ),
                            labelStyle: AppTextStyles.labelMedium
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          onPressed: () => _removeOption(index),
                          icon: Icon(Icons.close, color: cs.error, size: 20),
                          tooltip: 'Ta bort alternativ',
                        ),
                    ],
                  ),
                );
              }),

              // Add option button
              if (_optionControllers.length < 4)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'Lägg till alternativ',
                      style:
                          AppTextStyles.labelMedium.copyWith(color: cs.primary),
                    ),
                  ),
                ),

              const SizedBox(height: AppDimensions.spacingSm),

              // Multiple choice toggle
              Row(
                children: [
                  Switch(
                    value: _allowMultiple,
                    onChanged: (v) => setState(() => _allowMultiple = v),
                    activeThumbColor: cs.primary,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    'Tillåt flera val',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Avbryt',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  ElevatedButton(
                    onPressed: _isValid ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.surfaceContainerHighest,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                            Radius.circular(AppDimensions.borderRadiusS)),
                      ),
                    ),
                    child: const Text('Skapa'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
