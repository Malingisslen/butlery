/// Full-screen dialog for composing and submitting beta feedback.
/// Includes category selection, description field, optional email,
/// and a screenshot preview with removal option.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/services/feedback/feedback_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

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
        // A modal: X, never a back arrow (Komponentark v1:57, pattern 4).
        // Skarmar v12 etapp 9 #fbformular draws it on ink with paper text,
        // which is the subpage bar's own surface.
        appBar: ButleryTopBar.undersida(
          title: context.l10n.feedbackSendLabel,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: AppDimensions.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              Text(
                context.l10n.feedbackCategoryLabel,
                style: AppTextStyles.labelLarge,
              ),
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
              Text(
                context.l10n.feedbackDescriptionLabel,
                style: AppTextStyles.labelLarge,
              ),
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
              Text(
                context.l10n.feedbackEmailLabel,
                style: AppTextStyles.labelLarge,
              ),
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
                    Text(
                      context.l10n.feedbackScreenshotLabel,
                      style: AppTextStyles.labelLarge,
                    ),
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

              // The form's one saffron action (Skarmar v12 etapp 9
              // #fbformular, "Skicka"). Sending keeps the name and draws the
              // plate line under it, never a spinner in its place (K-06).
              HeroButton(
                key: const ValueKey('feedback.submit'),
                label: context.l10n.feedbackSendButton,
                onPressed: _submit,
                busy: _isSubmitting,
                expand: true,
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
      SnackBarUtils.showError(
        context,
        context.l10n.feedbackDescriptionRequired,
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
        SnackBarUtils.showSuccess(context, context.l10n.feedbackThanks);
      } else {
        SnackBarUtils.showError(context, context.l10n.feedbackSendFailed);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
