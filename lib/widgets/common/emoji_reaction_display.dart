// lib/widgets/common/emoji_reaction_display.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
      spacing: AppDimensions.space4,
      runSpacing: AppDimensions.space4,
      children: activeReactions.map((entry) {
        final emojiKey = entry.key;
        final userIds = entry.value;
        final hasReacted = userIds.contains(currentUserId);
        final displayEmoji = kReactionEmojis[emojiKey] ?? emojiKey;

        return Semantics(
          button: true,
          selected: hasReacted,
          label: '${emojiSemanticsLabel(context, emojiKey)}, ${userIds.length}',
          // The badge stays small; the tap, the focus ring and the press
          // fill cover a 48 dp box around it.
          child: ButleryControlFocus(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            child: Material(
              type: MaterialType.transparency,
              child: PressFill(
                surface: hasReacted ? PressSurface.raised : PressSurface.base,
                child: InkWell(
                  onTap: () => onReactionTap(emojiKey),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  child: ButleryControlFocus.box(
                    child: Container(
                      padding: AppDimensions.paddingAll4,
                      decoration: BoxDecoration(
                        // Your reaction is surface.selected (surfaceContainerHighest carries its
                        // values in both modes) with a real text.primary border, never an ink
                        // tint.
                        color: hasReacted
                            ? cs.surfaceContainerHighest
                            : cs.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
                        border: Border.all(
                          color: hasReacted ? cs.onSurface : cs.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayEmoji,
                            style: const TextStyle(
                              fontSize: AppDimensions.emojiGlyphInline,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.space4),
                          Text(
                            '${userIds.length}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: hasReacted
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
