import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

/// BUT-975: first-touch onboarding empty state for the Friends tab.
///
/// Replaces the generic icon/title/subtitle state with a branded surface
/// that explains *why* friends matter in a recipe app and gives two clear
/// entry points. Mirrors [MinaReceptEmptyState] so the social-onboarding
/// first impression matches the recipe-onboarding one (same illustration
/// language, headline/subtitle rhythm, primary + secondary CTA stack).
class FriendsEmptyState extends StatelessWidget {
  const FriendsEmptyState({
    super.key,
    required this.onInvite,
    required this.onFindByUsername,
  });

  /// Primary CTA — share an invitation link.
  final VoidCallback onInvite;

  /// Secondary CTA — jump to the "Find friends" search tab.
  final VoidCallback onFindByUsername;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VegetableIllustration(
              type: VegetableType.peaPod,
              size: 100,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              context.l10n.friendsEmptyHeadline,
              style: AppTextStyles.headlineMedium.copyWith(color: cs.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              context.l10n.friendsEmptySubtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            // Both CTAs are self-labeling button primitives — per
            // ui-conventions.md rule 6 they carry their own Semantics, so no
            // explicit Semantics wrapper is needed (or wanted).
            SizedBox(
              width: double.infinity,
              child: ActionButtons.primaryButton(
                context,
                label: context.l10n.socialInviteFriends,
                onPressed: onInvite,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            TextButton(
              onPressed: onFindByUsername,
              child: Text(context.l10n.friendsEmptyFindByUsername),
            ),
          ],
        ),
      ),
    );
  }
}
