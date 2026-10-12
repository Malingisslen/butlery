import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ButleryControlFocus.minSize),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The box stands on the form's left edge at the checkbox token's
          // size (tokens.json controls.checkbox, B-37); the padding around it
          // is the touch target, so it stays at least the minimum tall. The
          // visible text beside the box is the screen-reader stop for this
          // checkbox, so the box itself stays out of the tree.
          ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged(!accepted),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppDimensions.space12,
                  AppDimensions.space8,
                  AppDimensions.space12,
                ),
                child: SizedBox.square(
                  dimension: _boxSize,
                  child: Center(
                    child: Transform.scale(
                      scale: _boxSize / _materialBox,
                      child: SizedBox.square(
                        dimension: _materialBox,
                        child: Checkbox(
                          value: accepted,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: onChanged == null
                              ? null
                              : (value) => onChanged(value ?? false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            // The words around the links toggle the box.
            child: Semantics(
              checked: accepted,
              child: GestureDetector(
                onTap: onChanged == null ? null : () => onChanged(!accepted),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.space16),
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
      ),
    );
  }

  // Material draws its box at this size; the token's box is scaled from it.
  static const double _materialBox = 18;
  static const double _boxSize = 24;

  InlineSpan _link(
    BuildContext context, {
    required String label,
    required String text,
    required String route,
  }) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: ButleryLink.inline(
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
