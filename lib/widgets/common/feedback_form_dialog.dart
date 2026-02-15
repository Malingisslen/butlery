/// Full-screen dialog for composing and submitting beta feedback.
/// Includes category selection, description field, optional email,
/// and a screenshot preview with removal option.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/services/feedback/feedback_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Dialog that collects feedback details and submits via FeedbackService.
class FeedbackFormDialog extends StatefulWidget {
  final Uint8List? screenshot;

  const FeedbackFormDialog({super.key, this.screenshot});

  @override
  State<FeedbackFormDialog> createState() => _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends State<FeedbackFormDialog> {
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.bug;
  Uint8List? _screenshot;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _screenshot = widget.screenshot;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Skicka feedback',
            style: AppTextStyles.headerTitle.copyWith(
              color: cs.onPrimary,
            ),
          ),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: AppDimensions.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              Text('Kategori', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.spacingSm),
              DropdownButtonFormField<FeedbackCategory>(
                value: _category,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: FeedbackCategory.bug,
                    child: Text('Bugg'),
                  ),
                  DropdownMenuItem(
                    value: FeedbackCategory.featureRequest,
                    child: Text('Onskemol'),
                  ),
                  DropdownMenuItem(
                    value: FeedbackCategory.general,
                    child: Text('Ovrigt'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Description
              Text('Beskrivning', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.spacingSm),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Beskriv vad du upplevde...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Email (optional)
              Text('E-post (valfritt)', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.spacingSm),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'din@email.se',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Screenshot preview
              if (_screenshot != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Skarmavbild', style: AppTextStyles.labelLarge),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _screenshot = null),
                      tooltip: 'Ta bort skarmavbild',
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Container(
                  height: AppDimensions.heightXLarge,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Image.memory(
                    _screenshot!,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
              ],

              // Submit button
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: AppDimensions.spinnerSizeSmall,
                          height: AppDimensions.spinnerSizeSmall,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text('Skicka', style: AppTextStyles.labelLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ange en beskrivning')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final feedbackService = ServiceLocator.get<FeedbackService>();
      final email = _emailController.text.trim();

      final success = await feedbackService.submitFeedback(
        category: _category,
        description: description,
        email: email.isNotEmpty ? email : null,
        screenshot: _screenshot,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tack for din feedback!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte skicka feedback. Forsok igen.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
