import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_opacity.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/widgets/styled/butlery_code_field.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// The first step of enabling two-step verification: what it means, and
/// the button that starts it.
class MfaEnrollStartForm extends StatelessWidget {
  const MfaEnrollStartForm({
    super.key,
    required this.busy,
    required this.onStart,
  });

  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.mfaAppTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(context.l10n.mfaAppIntro),
            const SizedBox(height: AppDimensions.space16),
            HeroButton(
              key: const ValueKey('mfa.turnOn'),
              label: context.l10n.mfaTurnOn,
              onPressed: onStart,
              busy: busy,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The step where Butlery is added to the authenticator app and the app's
/// first code is typed back.
class MfaTotpSetupForm extends StatelessWidget {
  const MfaTotpSetupForm({
    super.key,
    required this.secretKey,
    required this.canOpenApp,
    required this.codeController,
    required this.busy,
    required this.onOpenApp,
    required this.onCopyKey,
    required this.onCancel,
    required this.onConfirm,
  });

  final String secretKey;

  /// False on the web, where no app can be handed the key.
  final bool canOpenApp;
  final TextEditingController codeController;
  final bool busy;
  final VoidCallback onOpenApp;
  final VoidCallback onCopyKey;
  final VoidCallback? onCancel;
  final VoidCallback onConfirm;

  /// "ABCD EFGH IJKL …": groups of four are easier to type into an app.
  static String groupKey(String key) {
    final groups = <String>[];
    for (var i = 0; i < key.length; i += 4) {
      groups.add(key.substring(i, i + 4 > key.length ? key.length : i + 4));
    }
    return groups.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.mfaSetupTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space16),
            if (canOpenApp) ...[
              KeyedSubtree(
                key: const ValueKey('mfa.openApp'),
                child: ActionButtons.secondaryButton(
                  context,
                  label: context.l10n.mfaSetupOpenApp,
                  onPressed: onOpenApp,
                  isExpanded: true,
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
            ],
            Text(
              canOpenApp
                  ? context.l10n.mfaSetupKeyIntroAlternative
                  : context.l10n.mfaSetupKeyIntro,
            ),
            const SizedBox(height: AppDimensions.space8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.space16),
              color: cs.surfaceContainerHighest,
              child: SelectableText(
                groupKey(secretKey),
                key: const ValueKey('mfa.secretKey'),
                style: AppTextStyles.bodyBold.copyWith(
                  color: cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.6,
                ),
              ),
            ),
            ButleryTextButton(
              key: const ValueKey('mfa.copyKey'),
              label: context.l10n.mfaSetupCopyKey,
              icon: ButleryIcons.copy,
              onPressed: onCopyKey,
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(context.l10n.mfaSetupCodeIntro),
            const SizedBox(height: AppDimensions.space8),
            ButleryCodeField(
              key: const ValueKey('mfa.codeField'),
              controller: codeController,
              label: context.l10n.mfaSixDigitCode,
              onSubmitted: (_) => onConfirm(),
            ),
            const SizedBox(height: AppDimensions.space16),
            Row(
              children: [
                Expanded(
                  child: ActionButtons.secondaryButton(
                    context,
                    label: context.l10n.commonCancel,
                    onPressed: onCancel,
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                // The view's one saffron action (Skarmar v12 del 3 #mfa;
                // Grafisk manual v6:219).
                Expanded(
                  child: HeroButton(
                    key: const ValueKey('mfa.confirm'),
                    label: context.l10n.mfaSetupConfirm,
                    onPressed: onConfirm,
                    busy: busy,
                    expand: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MfaErrorBanner extends StatelessWidget {
  const MfaErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.error.withValues(alpha: AppOpacity.onPaper40),
        ),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.triangleAlert,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppDimensions.space8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
