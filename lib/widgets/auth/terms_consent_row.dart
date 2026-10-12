import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_link.dart';

/// The consent a new account gives, on the sign-up form, before a guest start
/// and when a guest creates an account.
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
        // half the minimum touch target. The visible text beside the box is
        // the screen-reader stop for this checkbox, so the box itself stays
        // out of the tree.
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
          // Links are baseline WidgetSpans in one sentence: ButleryLink keeps
          // its hit area. The words around them toggle the box.
          child: Semantics(
            checked: accepted,
            child: GestureDetector(
              onTap: onChanged == null ? null : () => onChanged(!accepted),
              child: Padding(
                padding: const EdgeInsets.only(top: AppDimensions.space12),
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurface,
                    ),
                    children: [
                      TextSpan(text: context.l10n.authTermsConsentPrefix),
                      _link(
                        context,
                        label: context.l10n.a11yTermsOfServiceLink,
                        text: context.l10n.authTermsConsentTermsLink,
                        route: Routes.termsOfService,
                      ),
                      TextSpan(text: context.l10n.authTermsAcceptMiddle),
                      _link(
                        context,
                        label: context.l10n.a11yPrivacyPolicyLink,
                        text: context.l10n.authTermsConsentPrivacyLink,
                        route: Routes.privacyPolicy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InlineSpan _link(
    BuildContext context, {
    required String label,
    required String text,
    required String route,
  }) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: ButleryLink(
      semanticLabel: label,
      onTap: () => Navigator.pushNamed(context, route),
      child: Text(text, style: _linkStyle(context)),
    ),
  );

  // text.link (R8-11 = A).
  TextStyle _linkStyle(BuildContext context) =>
      AppTextStyles.bodySmall.copyWith(
        color: context.modeColors.textLink,
        decoration: TextDecoration.underline,
        decorationColor: context.modeColors.textLink,
      );
}
