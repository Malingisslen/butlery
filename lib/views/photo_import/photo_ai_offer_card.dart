// lib/views/photo_import/photo_ai_offer_card.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:butlery/widgets/common/utility_components.dart';

/// Offers to let AI read the photo after the phone could not. Takes plain
/// parameters so it stays independent of the view model; the photo leaves the
/// device only through [onAccept].
class PhotoAiOfferCard extends StatelessWidget {
  const PhotoAiOfferCard({
    super.key,
    required this.reason,
    required this.consented,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final PhotoAiOfferReason reason;

  /// Whether the AI-processing consent is already given; the consent sentence
  /// is then left out of the question.
  final bool consented;

  /// Both buttons are off while a reading is running.
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final reasonLine = switch (reason) {
      PhotoAiOfferReason.phoneCouldNotRead =>
        l10n.photoAiOfferPhoneCouldNotRead,
      PhotoAiOfferReason.noRecipeFound => l10n.photoAiOfferNoRecipeFound,
      PhotoAiOfferReason.handwriting => l10n.photoAiOfferHandwriting,
    };
    final question = consented
        ? l10n.photoAiOfferQuestionConsented
        : l10n.photoAiOfferQuestion;

    // A live region so a screen reader speaks the offer when it appears.
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$reasonLine $question',
      child: StyledCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Text(
                reasonLine,
                style: AppTextStyles.titleSmall.copyWith(color: cs.onSurface),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            ExcludeSemantics(
              child: Text(
                question,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            UtilityComponents.primaryButton(
              context,
              label: l10n.photoAiOfferAccept,
              onPressed: busy ? null : onAccept,
              isExpanded: true,
            ),
            const SizedBox(height: AppDimensions.space8),
            UtilityComponents.secondaryButton(
              context,
              label: l10n.photoAiOfferDecline,
              onPressed: busy ? null : onDecline,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
