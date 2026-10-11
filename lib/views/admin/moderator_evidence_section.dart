import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';

/// Shows the saved copy as plain `Text` only: it is untrusted user content,
/// so no markdown and no link detection.
class ModeratorEvidenceSection extends StatelessWidget {
  final ReportEvidenceState state;
  const ModeratorEvidenceSection({required this.state, super.key});

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
    final heading = capturedAt == null
        ? l10n.moderatorEvidenceHeading
        : l10n.moderatorEvidenceHeadingAt(
            ContextualTimeFormatter.dateTime(
              capturedAt,
              localeName: l10n.localeName,
            ),
          );

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
      ],
    );
  }
}
