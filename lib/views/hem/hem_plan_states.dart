// lib/views/hem/hem_plan_states.dart
//
// HEM-HERO: the week's plan while it loads and when it could not be read,
// on Hem above the library (see hem_section.dart for the sources).
//
//   Skarmar v12 del 4 #hemladdar (:616-650): the plate line with "Hämtar
//       veckans plan …", and a still skeleton only after 300 ms.
//   Skarmar v12 del 4 #hemfel (:704-742): what happened, what was kept,
//       "Försök igen" and "Visa sparad plan"; the library stays
//       (produktregler.md:291-293).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// #hemladdar: the plate line with what is being fetched, and after 300 ms a
/// still skeleton of the card (produktregler.md:163; "Skelettet visas först
/// efter 300 ms — en snabb start ska aldrig blinka").
class HemPlanLoading extends StatefulWidget {
  const HemPlanLoading({super.key});

  /// How long a fast start stays without a skeleton.
  static const Duration skeletonDelay = Duration(milliseconds: 300);

  static const Key skeletonKey = ValueKey('hem-plan-skeleton');

  @override
  State<HemPlanLoading> createState() => _HemPlanLoadingState();
}

class _HemPlanLoadingState extends State<HemPlanLoading> {
  Timer? _timer;
  bool _showSkeleton = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(HemPlanLoading.skeletonDelay, () {
      if (mounted) setState(() => _showSkeleton = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final message = context.l10n.hemLoadingPlan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingMd + 2,
        AppDimensions.spacingLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: AppDimensions.spacingSm + 2,
            runSpacing: AppDimensions.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // The line carries the text as its label, so it is read once.
              PlateLine(width: 120, semanticLabel: message),
              ExcludeSemantics(
                child: Text(
                  message,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_showSkeleton) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            // Still, never shimmering. surface.raised, colorScheme
            // .primaryContainer: #E6EAD9 light, #2F4437 dark
            // (tokens.json:108-111).
            ExcludeSemantics(
              child: Container(
                key: HemPlanLoading.skeletonKey,
                height: 112,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusControl,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// #hemfel: the week's plan could not be read. The three parts of
/// content-style-guide.md:87-97 and produktregler.md:293 (what happened,
/// what was kept, what you can do): the first two in the section error box
/// (InlineError, Komponentark v1:755-758), then "Försök igen" and "Visa
/// sparad plan" under it. The rest of Hem stands.
///
/// Interpretation: #hemfel :226 draws "Försök igen" outlined in ink and the
/// box in a 1.5 px text.danger line; the box keeps InlineError's drawn
/// anatomy and the retry is the outlined button of the theme.
class HemPlanError extends StatelessWidget {
  const HemPlanError({
    required this.onRetry,
    required this.onShowSavedPlan,
    super.key,
  });

  final VoidCallback onRetry;
  final VoidCallback onShowSavedPlan;

  static const Key retryKey = ValueKey('hem-plan-retry');
  static const Key showSavedPlanKey = ValueKey('hem-show-saved-plan');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingMd + 2,
        AppDimensions.spacingLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // What happened and what was kept, in the section error box.
          // What happened. #hemfel draws a cause ("Servern svarade inte") and
          // "Din plan är sparad", but readWeek cannot tell which of those is
          // true (it fails the same way offline, signed out or denied), and a
          // failure never claims what it does not know (content-style-guide.md,
          // the three-part error). So only what happened is said here.
          InlineError(what: l10n.hemPlanErrorWhat),
          const SizedBox(height: AppDimensions.spacingSm),
          // What you can do: the two actions under the text, as #hemfel
          // :225-228 draws them. A Wrap, so 200 % text stacks them.
          Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingSm,
            children: [
              OutlinedButton.icon(
                key: retryKey,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppDimensions.minTouchTarget),
                ),
                onPressed: onRetry,
                icon: const ButleryIcon(ButleryIcons.refreshCw),
                label: Text(l10n.commonRetry),
              ),
              TextButton(
                key: showSavedPlanKey,
                // text.link: #8A5212 light, #DCA968 dark
                // (tokens.json:228-231), drawn in the link colour (#hemfel
                // :227).
                style: TextButton.styleFrom(
                  foregroundColor: context.modeColors.info,
                  minimumSize: const Size(0, AppDimensions.minTouchTarget),
                ),
                onPressed: onShowSavedPlan,
                child: Text(l10n.hemShowSavedPlan),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
