// lib/widgets/messaging/components/system_message_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Widget for displaying system messages in chat.
///
/// [onDismiss] is OPT-IN (BUT-1904). Left null the widget draws no icon, no
/// gesture and no `Semantics` — which is the condition for its two other uses
/// (the group system rows and the "du gick med här" divider) looking and
/// behaving as they did before the duplicate-guard notice gained a dismiss
/// control. The pill's own subtree did change: the `Text` is now `Flexible`
/// inside a min-width `Row` so the icon can sit beside it.
class SystemMessageWidget extends StatelessWidget {
  final String content;

  /// Non-null only for the duplicate-guard notice, which its own sender may
  /// clear. See ADR-0009.
  final VoidCallback? onDismiss;

  /// Screen-reader label for the dismiss control. Required whenever
  /// [onDismiss] is set.
  ///
  /// Name the ACTION, not the notice. Measured on the built semantics node: the
  /// child `Text` is CONCATENATED onto this label rather than replaced by it,
  /// so a label that restated the notice made the row announce the same
  /// sentence twice.
  final String? dismissSemanticsLabel;

  const SystemMessageWidget({
    super.key,
    required this.content,
    this.onDismiss,
    this.dismissSemanticsLabel,
  }) : assert(
         onDismiss == null || dismissSemanticsLabel != null,
         'a dismissible notice must carry its own Semantics label',
       );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: cs.outline.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              content,
              style: AppTextStyles.labelSmall.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: AppDimensions.paddingS),
            Icon(
              Icons.close,
              size: AppDimensions.iconSizeS,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Center(
        child: onDismiss == null
            ? pill
            // MEASURED, not assumed (BUT-1904): the pill is shorter than
            // `AppDimensions.minTouchTarget`. The tap region is constrained
            // here rather than the pill being grown, so the notice still looks
            // like the rows beside it.
            //
            // The gesture is on the CONSTRAINED BOX, not on the Padding above
            // it: a tap inside the row but outside this box must do nothing.
            // `message_bubble_duplicate_blocked_test.dart` pins that, because
            // BUT-1837 was a `Semantics` node whose rect did not match its
            // widget and swallowed taps across the viewport.
            : Semantics(
                label: dismissSemanticsLabel,
                button: true,
                container: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimensions.minTouchTarget,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    // Both factors are load-bearing. A plain `Center`
                    // EXPANDS to the loose constraints it is given, which
                    // made this gesture cover almost the whole screen —
                    // measured 768x584 in a widget test, i.e. a tap
                    // anywhere on the row would have cleared the notice.
                    // Sizing to the child keeps the hit region on the
                    // pill, while the ConstrainedBox above still lifts it
                    // to the house minimum height.
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: pill,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Widget for displaying reply preview in message bubble.
class ReplyPreviewWidget extends StatelessWidget {
  final String senderName;
  final String content;
  final bool isFromCurrentUser;

  const ReplyPreviewWidget({
    super.key,
    required this.senderName,
    required this.content,
    required this.isFromCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (isFromCurrentUser ? cs.surfaceContainerHighest : cs.secondary)
            .withValues(alpha: AppDimensions.opacityLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border(
          left: BorderSide(color: cs.secondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: AppTextStyles.labelMedium.copyWith(
              color: isFromCurrentUser
                  ? cs.surfaceContainerHighest.withValues(
                      alpha: AppDimensions.opacityVeryDark,
                    )
                  : cs.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            content,
            style: AppTextStyles.labelSmall.copyWith(
              color: isFromCurrentUser
                  ? cs.surfaceContainerHighest.withValues(
                      alpha: AppDimensions.opacityDark,
                    )
                  : cs.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying message avatar.
class MessageAvatarWidget extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final Widget? avatarImage;

  const MessageAvatarWidget({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.avatarImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.secondary.withValues(alpha: AppDimensions.opacityLight),
      ),
      child: avatarImage ?? _buildFallback(cs),
    );
  }

  Widget _buildFallback(ColorScheme cs) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: AppTextStyles.labelMedium.copyWith(color: cs.primary),
      ),
    );
  }
}
