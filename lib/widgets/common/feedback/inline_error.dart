/// The three-part error as a line in a view, a dialog or a sheet
/// (content-style-guide.md:87-97).
///
/// 1. What happened ([what]), concrete and without blame.
/// 2. What was kept ([preserved]), only when something was at stake.
/// 3. What you can do ([actionLabel] / [onAction]), as a button.
///
/// The anatomy is the drawn error boundary (Komponentark v1:755-758): a 1 px
/// text.danger outline with the 8 px control radius, the triangle-alert
/// glyph in text.danger, a bold title in text.primary and the body in
/// text.body. Colours, both modes (tokens.json):
/// - outline and glyph: colorScheme.error = text.danger, #9C3B23 light,
///   #DE9078 dark (tokens.json:96-98);
/// - title: colorScheme.onSurface = text.primary, #24382C / #F5F4ED
///   (tokens.json:54-56);
/// - body: AppModeColors.textBody = text.body, #37453A / #F5F4ED
///   (tokens.json:58-60);
/// - background: colorScheme.surface = surface.base, #F5F4ED / #17251D
///   (tokens.json:104-106).
///
/// Screen readers: the box has the alert role and its text is a live
/// region, so it is read when it appears without moving focus
/// (Butlery tillganglighetshandoff.dc.html:172, "Läses upp utan
/// fokusbyte"). Flutter does not allow both on one node, so the role sits on
/// the box and the live region on the text inside it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// An error line with what happened, what was kept and one action.
class InlineError extends StatelessWidget {
  const InlineError({
    required this.what,
    this.preserved,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback.',
       );

  /// What happened, for example "Koden kunde inte skickas."
  final String what;

  /// What was kept, for example "Din text ligger kvar." Null when nothing
  /// was at stake (content-style-guide.md:92).
  final String? preserved;

  /// The action, named for what it does: Försök igen, never OK
  /// (content-style-guide.md:93, :96).
  final String? actionLabel;

  /// What the action does.
  final VoidCallback? onAction;

  /// The box. The key is for tests, not identity.
  static const Key boxKey = ValueKey<String>('inlineError.box');

  /// The action. The key is for tests, not identity.
  static const Key actionKey = ValueKey<String>('inlineError.action');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final danger = cs.error;
    final bodyColor = AppModeColors.textBody(theme.brightness);
    final preserved = this.preserved;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;

    return Semantics(
      container: true,
      role: SemanticsRole.alert,
      child: Material(
        key: boxKey,
        color: cs.surface,
        // Komponentark v1:755 border-radius:8px = radius.control.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          side: BorderSide(
            color: danger,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingModerate,
            AppDimensions.paddingM,
            AppDimensions.spacingXs,
            AppDimensions.paddingM,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingXxs),
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: danger,
                    size: AppDimensions.iconSize18,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingMs),
              Expanded(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        what,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      if (preserved != null) ...[
                        const SizedBox(height: AppDimensions.spacingXxs),
                        Text(
                          preserved,
                          style: AppTextStyles.captionBase.copyWith(
                            color: bodyColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  key: actionKey,
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
