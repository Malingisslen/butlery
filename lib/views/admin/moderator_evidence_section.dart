import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/admin/moderator_labels.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// Shows the saved copy as plain `Text` only: it is untrusted user content,
/// so no markdown and no link detection.
class ModeratorEvidenceSection extends StatelessWidget {
  final ReportEvidenceState state;
  const ModeratorEvidenceSection({
    required this.state,
    this.reopened = false,
    this.onKeepLonger,
    super.key,
  });

  /// The copy was taken when the case was reopened, so it shows the content
  /// as it is now rather than as it was when reported.
  final bool reopened;

  /// Offered on a captured copy that is not yet kept past its case.
  final VoidCallback? onKeepLonger;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final muted = AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant);

    final evidence = state is ReportEvidenceLoaded
        ? (state as ReportEvidenceLoaded).evidence
        : null;
    if (evidence == null) {
      return Text(l10n.moderatorEvidenceNone, style: muted);
    }

    final capturedAt = evidence.capturedAt;
    final time = capturedAt == null
        ? null
        : ContextualTimeFormatter.dateTime(
            capturedAt,
            localeName: l10n.localeName,
          );
    // A kept copy was taken when the report came in, not at the reopen.
    final heading = reopened && !evidence.isFrozen
        ? (time == null
              ? l10n.moderatorEvidenceNowHeading
              : l10n.moderatorEvidenceNowHeadingAt(time))
        : (time == null
              ? l10n.moderatorEvidenceHeading
              : l10n.moderatorEvidenceHeadingAt(time));

    final String? outcomeLine = switch (evidence.outcome) {
      EvidenceOutcome.captured => null,
      EvidenceOutcome.missing => l10n.moderatorEvidenceMissing,
      EvidenceOutcome.notVisibleToReporter => l10n.moderatorEvidenceNotVisible,
      EvidenceOutcome.ownerMismatch => l10n.moderatorEvidenceOwnerMismatch,
      EvidenceOutcome.unsupportedType ||
      EvidenceOutcome.invalidRef => l10n.moderatorEvidenceUnsupported,
      EvidenceOutcome.captureFailed ||
      EvidenceOutcome.unknown => l10n.moderatorEvidenceFailed,
    };

    final frozen = evidence.frozen;
    final captured = evidence.outcome == EvidenceOutcome.captured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: AppTextStyles.labelMedium.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        if (outcomeLine != null)
          Text(outcomeLine, style: muted)
        else ...[
          for (final (field, value) in evidence.text)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space4),
              child: Text(
                value,
                key: ValueKey('evidence-$field'),
                style: AppTextStyles.bodySmall,
              ),
            ),
          if (evidence.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space4),
              child: Text(l10n.moderatorEvidenceTruncated, style: muted),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space4),
            child: Text(l10n.moderatorEvidenceTextOnly, style: muted),
          ),
        ],
        if (frozen != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space4),
            child: Text(
              l10n.moderatorFrozenUntilLine(
                DateFormat.yMMMd(
                  l10n.localeName,
                ).format(frozen.until.toLocal()),
                freezeReasonLabel(l10n, frozen.reason),
              ),
              key: const ValueKey('evidence-frozen-line'),
              style: muted,
            ),
          )
        else if (captured && onKeepLonger != null)
          Align(
            alignment: Alignment.centerLeft,
            child: ActionButtons.textButton(
              context,
              key: const ValueKey('evidence-keep-longer'),
              label: l10n.moderatorKeepLonger,
              onPressed: onKeepLonger,
            ),
          ),
      ],
    );
  }
}
