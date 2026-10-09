import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_reason.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

/// Reusable report dialog for any content type.
///
/// Usage:
/// ```dart
/// ReportContentDialog.show(
///   context: context,
///   contentType: ContentType.recipe,
///   contentId: recipe.id,
///   contentOwnerId: recipe.userId,
/// );
/// ```
class ReportContentDialog {
  static Future<void> show({
    required BuildContext context,
    required ContentType contentType,
    required String contentId,
    String? contentOwnerId,
  }) async {
    final outcome = await _showReasonDialog(context, contentType);
    if (outcome == null || !context.mounted) return;

    // One id for this report, kept by Försök igen, so a retry after a write
    // that landed without an answer cannot file the report twice.
    final reportId = ServiceLocator.get<ReportService>().newReportId();
    await _submit(
      context,
      reportId: reportId,
      contentType: contentType,
      contentId: contentId,
      contentOwnerId: contentOwnerId,
      outcome: outcome,
    );
  }

  /// Sends the report and says how it went: "Anmälan har skickats", or the
  /// failure snackbar with what happened and Försök igen, which sends the
  /// same report again (content-style-guide.md:87-97).
  static Future<void> _submit(
    BuildContext context, {
    required String reportId,
    required ContentType contentType,
    required String contentId,
    required String? contentOwnerId,
    required _ReportOutcome outcome,
  }) async {
    var success = false;
    try {
      final reportService = ServiceLocator.get<ReportService>();
      success = await reportService.submitReport(
        reportId: reportId,
        contentType: contentType,
        contentId: contentId,
        reason: outcome.reason,
        contentOwnerId: contentOwnerId,
        description: outcome.description,
      );
    } catch (_) {
      success = false;
    }

    if (!context.mounted) return;
    if (success) {
      SnackBarUtils.showSuccess(context, context.l10n.reportSubmitted);
      return;
    }
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.reportSubmitFailed,
      action: FailureAction.retry(() {
        if (!context.mounted) return;
        _submit(
          context,
          reportId: reportId,
          contentType: contentType,
          contentId: contentId,
          contentOwnerId: contentOwnerId,
          outcome: outcome,
        );
      }),
    );
  }

  static Future<_ReportOutcome?> _showReasonDialog(
    BuildContext context,
    ContentType contentType,
  ) => showDialog<_ReportOutcome>(
    context: context,
    builder: (_) => _ReportReasonDialog(contentType: contentType),
  );
}

/// Owns the description controller so it is disposed with the dialog, after
/// its exit animation, not while the closing field still listens to it.
class _ReportReasonDialog extends StatefulWidget {
  const _ReportReasonDialog({required this.contentType});

  final ContentType contentType;

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  ReportReason? _selectedReason;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // BUT-531: when "Other" is selected, surface a TextField so the
    // reporter can describe the issue. Required when "Other" is chosen
    // (Google Play appeal policy expects a reporter description); the
    // submit button stays disabled until non-empty.
    final isOther = _selectedReason == ReportReason.other;
    final descriptionFilled = _descriptionController.text.trim().isNotEmpty;
    final canSubmit =
        _selectedReason != null && (!isOther || descriptionFilled);

    return AlertDialog(
      // "Anmäl det här receptet" for a recipe, as drawn (Skarmar v12
      // etapp 9 #fbanmal:507). Interpretation: the other content types
      // have no drawn title and say "Anmäl innehåll".
      title: Text(
        widget.contentType == ContentType.recipe
            ? l10n.reportDialogTitleRecipe
            : l10n.reportDialogTitle,
      ),
      // Five 48 dp reasons, the free-text field and the note do not fit
      // a short screen or large text, so the content scrolls rather
      // than clipping (tillganglighetshandoff:85, 200 % text).
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The drawn intro under the title (Skarmar v12 etapp 9
          // #fbanmal): who reads the report, a person
          // (produktregler.md).
          Text(
            l10n.reportDialogIntro,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<ReportReason>(
            groupValue: _selectedReason,
            onChanged: (value) => setState(() => _selectedReason = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ReportReason.offered
                  .map(
                    // Each reason is a 48 dp row with the canonical focus
                    // ring around it, never a saffron focus tint
                    // (Skarmar v12 etapp 9 #fbanmal, "48 px radhöjd";
                    // Grafisk manual v6:209, :381).
                    (reason) => ButleryControlFocus(
                      child: RadioListTile<ReportReason>(
                        title: Text(reason.label(l10n)!),
                        value: reason,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (isOther) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.reportDescriptionHint,
                // "Krävs när du väljer Annat." with the 0 / 500 counter
                // beside it, as drawn (#fbanmal:516;
                // produktregler.md). Interpretation: the drawn bold
                // on "Krävs" is left out; the helper is plain text.
                helperText: l10n.reportDescriptionRequiredHelper,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // "Vi bedömer mot våra riktlinjer — den version du ser nu är
          // den vi dömer efter." (#fbanmal; produktregler.md).
          _GuidelinesNote(
            prefix: l10n.reportDialogGuidelinesNotePrefix,
            linkText: l10n.reportDialogGuidelinesLink,
            suffix: l10n.reportDialogGuidelinesNoteSuffix,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        // The dialog's one saffron action, "Skicka anmälan" (Skarmar
        // v12 etapp 9 #fbanmal:523; Komponentark v1:843-844).
        // Interpretation that departs from the drawing: #fbanmal draws
        // a full-width 48 px block with no Avbryt beside it; here it is
        // sized to its label in the AlertDialog action row next to
        // Avbryt. The dialog says "anmälan" throughout, as drawn.
        FilledButton(
          key: const ValueKey('reportContent.submit'),
          style:
              ComponentThemes.heroButtonStyle(
                Theme.of(context).colorScheme,
              ).copyWith(
                minimumSize: const WidgetStatePropertyAll(
                  Size(0, AppDimensions.minTouchTarget),
                ),
              ),
          onPressed: canSubmit
              ? () => Navigator.pop(
                  context,
                  _ReportOutcome(
                    reason: _selectedReason!,
                    description: isOther
                        ? _descriptionController.text.trim()
                        : null,
                  ),
                )
              : null,
          child: Text(l10n.reportSubmit),
        ),
      ],
    );
  }
}

class _ReportOutcome {
  const _ReportOutcome({required this.reason, this.description});

  final ReportReason reason;
  final String? description;
}

/// Inline note linking to community guidelines from the report dialog.
/// Tap on the linked phrase opens the guidelines view; the visible
/// version is implicitly the version stamped on the resulting report record.
class _GuidelinesNote extends StatelessWidget {
  const _GuidelinesNote({
    required this.prefix,
    required this.linkText,
    required this.suffix,
  });

  final String prefix;
  final String linkText;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall ?? AppTextStyles.bodySmall;
    return Text.rich(
      TextSpan(
        // text.secondary, not the body colour at 75 %: opacity is never a
        // colour (tokens.json:40-53).
        style: base.copyWith(color: theme.colorScheme.onSurfaceVariant),
        children: [
          TextSpan(text: '$prefix '),
          // BUT-1446: WidgetSpan + Semantics(link:) so the guidelines link is
          // announced as a link with a name (was an inline TapGestureRecognizer
          // — no link role). Dropping the
          // recognizer also lets this be a StatelessWidget.
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ButleryLink(
              semanticLabel: linkText,
              onTap: () =>
                  Navigator.of(context).pushNamed(Routes.communityGuidelines),
              child: Text(
                linkText,
                style: base.copyWith(
                  color: context.modeColors.textLink,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          TextSpan(text: ' $suffix'),
        ],
      ),
    );
  }
}
