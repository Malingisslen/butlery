import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/layout/inline_widget_span.dart';

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
          // The visible text beside the box is the screen-reader stop for this
          // checkbox, so the box itself stays out of the tree.
          // The box stands on the form's left edge (tokens.json
          // controls.checkbox): the 48 dp square is pulled left so its padding
          // hangs outside the row.
          ExcludeSemantics(
            child: SizedBox(
              width: ButleryCheckbox.boxSize + AppDimensions.space8,
              height: ButleryControlFocus.minSize,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: ButleryControlFocus.minSize,
                maxWidth: ButleryControlFocus.minSize,
                child: Transform.translate(
                  offset: const Offset(
                    -(ButleryControlFocus.minSize - ButleryCheckbox.boxSize) /
                        2,
                    0,
                  ),
                  child: ButleryCheckbox(
                    value: accepted,
                    onChanged: onChanged,
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

  InlineSpan _link(
    BuildContext context, {
    required String label,
    required String text,
    required String route,
  }) => inlineWidgetSpan(
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
