/// Full-screen dialog for composing and submitting beta feedback.
/// Includes category selection, description field, optional email,
/// and a screenshot preview with removal option.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/services/feedback/feedback_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';

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
        appBar: AdaptiveAppBar(
          title: context.l10n.feedbackSendLabel,
          titleStyle: AppTextStyles.headerTitle.copyWith(
            color: cs.onPrimary,
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
              Text(context.l10n.feedbackCategoryLabel,
                  style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.spacingSm),
              DropdownButtonFormField<FeedbackCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: FeedbackCategory.bug,
                    child: Text(context.l10n.feedbackCategoryBug),
                  ),
                  DropdownMenuItem(
                    value: FeedbackCategory.featureRequest,
                    child: Text(context.l10n.feedbackCategoryFeatureRequest),
                  ),
                  DropdownMenuItem(
                    value: FeedbackCategory.general,
                    child: Text(context.l10n.feedbackCategoryGeneral),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Description
              Text(context.l10n.feedbackDescriptionLabel,
                  style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.spacingSm),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                minLines: 3,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: context.l10n.feedbackDescriptionHint,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Email (optional)
              Text(context.l10n.feedbackEmailLabel,
                  style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.spacingSm),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: context.l10n.feedbackEmailHint,
                  border: const OutlineInputBorder(
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
                    Text(context.l10n.feedbackScreenshotLabel,
                        style: AppTextStyles.labelLarge),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _screenshot = null),
                      tooltip: context.l10n.feedbackRemoveScreenshot,
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
                      ? LoadingIndicator(
                          size: AppDimensions.spinnerSizeSmall,
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        )
                      : Text(context.l10n.feedbackSendButton,
                          style: AppTextStyles.labelLarge),
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
        SnackBar(content: Text(context.l10n.feedbackDescriptionRequired)),
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
          SnackBar(content: Text(context.l10n.feedbackThanks)),
        );
      } else {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.error,
            content: Text(
              context.l10n.feedbackSendFailed,
              style: TextStyle(color: cs.onError),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
