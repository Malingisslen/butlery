import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// P6-U05: the item a user had typed but not added when their role on the
/// list dropped to read-only, kept in the view until they close it.
///
/// A notice box like [CollaborativeUpdatedByNotice]: surface.tint.warning fill, no
/// border, the control radius, text.body (B83-2e).
/// The typed text is body text, so it is never cut off
/// (content-style-guide.md) and can be selected as well as copied.
class CollaborativeUnaddedTextNotice extends StatelessWidget {
  const CollaborativeUnaddedTextNotice({
    super.key,
    required this.text,
    required this.onCopy,
    required this.onClose,
  });

  final String text;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = AppModeColors.textBody(Theme.of(context).brightness);
    return Padding(
      key: const ValueKey('collaborativeShopping.unaddedText'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      child: Material(
        color: context.modeColors.surfaceTintWarning,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space12,
            AppDimensions.space8,
            AppDimensions.space4,
            AppDimensions.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.roleLoweredShoppingUnsaved,
                style: AppTextStyles.captionBase.copyWith(color: body),
              ),
              const SizedBox(height: AppDimensions.space4),
              SelectableText(
                text,
                style: AppTextStyles.bodyMedium.copyWith(color: body),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  children: [
                    ButleryTextButton(
                      onPressed: onCopy,
                      label: l.roleLoweredCopyText,
                    ),
                    ButleryTextButton(
                      onPressed: onClose,
                      label: l.commonClose,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// BUT-2187: "Listan uppdaterades av namn" — shown in
/// the header when someone else updates this shared list while it is open.
///
/// Drawn as a list row (v10-2): a warning plate with the warning edge and a
/// hairline under it, the text in text.body, and a dismiss control. Sits
/// between the header's participant row and "Lägg till vara".
class CollaborativeUpdatedByNotice extends StatelessWidget {
  const CollaborativeUpdatedByNotice({
    super.key,
    required this.text,
    required this.onDismiss,
  });

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final body = AppModeColors.textBody(Theme.of(context).brightness);
    // Keyed on the text so a screen reader announces each distinct notice
    // once (a rebuild of the same text, or the same notice reappearing
    // unchanged, stays silent) — same pattern as ConflictBanner.
    return KeyedSubtree(
      key: ValueKey(text),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
          decoration: BoxDecoration(
            color: context.modeColors.surfaceTintWarning,
            border: Border(
              left: BorderSide(
                color: AppModeColors.textWarning(Theme.of(context).brightness),
                width: 3,
              ),
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space12,
                    vertical: AppDimensions.space8,
                  ),
                  child: Text(
                    text,
                    style: AppTextStyles.captionBase.copyWith(color: body),
                  ),
                ),
              ),
              SizedBox(
                width: AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                child: ButleryCloseButton(
                  semanticLabel: context.l10n.a11yShoppingListUpdatedByDismiss,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
