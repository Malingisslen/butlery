import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_link.dart';

/// "Jag accepterar Villkor och Integritetspolicy": the consent a new account
/// gives, on the sign-up form and before a guest start.
class TermsConsentRow extends StatelessWidget {
  const TermsConsentRow({
    required this.accepted,
    required this.onChanged,
    super.key,
  });

  final bool accepted;

  /// Null while the form is busy: the box and its words stop toggling.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onChanged = this.onChanged;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A >=48dp tap target (WCAG 2.5.5 / EAA) while the visible box stays
        // compact. BUT-1426: the old SizedBox(24,24) clamped the hit area to
        // half the minimum touch target. The visible "I accept" text beside
        // the box is the screen-reader stop for this checkbox, so the box
        // itself stays out of the tree.
        ExcludeSemantics(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Checkbox(
              value: accepted,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged(value ?? false),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.space8),
        Expanded(
          // BUT-1426: the inline ToS / Privacy links were
          // TapGestureRecognizer spans — no link role, no accessible name.
          // The plain-label words toggle the checkbox.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                checked: accepted,
                child: GestureDetector(
                  onTap: onChanged == null ? null : () => onChanged(!accepted),
                  child: Text(
                    context.l10n.authTermsAcceptPrefix,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              ButleryLink(
                semanticLabel: context.l10n.a11yTermsOfServiceLink,
                onTap: () =>
                    Navigator.pushNamed(context, Routes.termsOfService),
                child: Text(
                  context.l10n.authTermsOfService,
                  style: _linkStyle(context),
                ),
              ),
              Text(
                context.l10n.authTermsAcceptMiddle,
                style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
              ),
              ButleryLink(
                semanticLabel: context.l10n.a11yPrivacyPolicyLink,
                onTap: () => Navigator.pushNamed(context, Routes.privacyPolicy),
                child: Text(
                  context.l10n.profilePrivacyPolicy,
                  style: _linkStyle(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // text.link (R8-11 = A).
  TextStyle _linkStyle(BuildContext context) =>
      AppTextStyles.bodySmall.copyWith(
        color: context.modeColors.textLink,
        decoration: TextDecoration.underline,
        decorationColor: context.modeColors.textLink,
      );
}
