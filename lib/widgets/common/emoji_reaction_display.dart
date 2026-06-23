// lib/widgets/common/emoji_reaction_display.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';

/// Displays compact reaction badges with counts below a comment.
/// Each badge shows the emoji and the number of users who reacted.
/// Badges are highlighted when the current user has reacted.
/// Tapping a badge toggles the current user's reaction.
class EmojiReactionDisplay extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final void Function(String emoji) onReactionTap;

  const EmojiReactionDisplay({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Only show emojis that have at least one reaction
    final activeReactions = reactions.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (activeReactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXxs,
      children: activeReactions.map((entry) {
        final emojiKey = entry.key;
        final userIds = entry.value;
        final hasReacted = userIds.contains(currentUserId);
        final displayEmoji = kReactionEmojis[emojiKey] ?? emojiKey;

        return Semantics(
          button: true,
          label: '${emojiSemanticsLabel(context, emojiKey)}, ${userIds.length}',
          child: GestureDetector(
            onTap: () => onReactionTap(emojiKey),
            child: Container(
              padding: AppDimensions.paddingSymmetric6x2,
              decoration: BoxDecoration(
                color: hasReacted
                    ? cs.primary.withValues(
                        alpha: AppDimensions.opacityVeryLight,
                      )
                    : cs.surface.withValues(alpha: AppDimensions.opacityHalf),
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusM,
                ),
                border: Border.all(
                  color: hasReacted
                      ? cs.primary.withValues(
                          alpha: AppDimensions.opacityMediumLight,
                        )
                      : cs.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayEmoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: AppDimensions.spacingXxs),
                  Text(
                    '${userIds.length}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: hasReacted ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: hasReacted
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
