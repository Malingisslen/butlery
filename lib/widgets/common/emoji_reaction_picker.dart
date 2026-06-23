// lib/widgets/common/emoji_reaction_picker.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';

/// Available emoji reactions for comments.
/// Maps internal key to display emoji.
const Map<String, String> kReactionEmojis = {
  'thumbs_up': '\u{1F44D}',
  'heart': '\u{2764}\u{FE0F}',
  'fire': '\u{1F525}',
  'laughing': '\u{1F602}',
  'yum': '\u{1F60B}',
  'thinking': '\u{1F914}',
};

/// Compact row of emoji buttons for reacting to comments.
/// Displays 6 predefined emojis in a horizontal row with tap and hover effects.
/// Square container design per project conventions.
class EmojiReactionPicker extends StatelessWidget {
  final void Function(String emoji) onReactionSelected;

  const EmojiReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppDimensions.paddingSymmetric4x3,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: kReactionEmojis.entries.map((entry) {
          return _EmojiButton(
            emojiKey: entry.key,
            emoji: entry.value,
            onTap: () => onReactionSelected(entry.key),
          );
        }).toList(),
      ),
    );
  }
}

String emojiSemanticsLabel(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'thumbs_up' => l10n.reactionThumbsUp,
    'heart' => l10n.reactionHeart,
    'fire' => l10n.reactionFire,
    'laughing' => l10n.reactionLaughing,
    'yum' => l10n.reactionYum,
    'thinking' => l10n.reactionThinking,
    _ => key.replaceAll('_', ' '),
  };
}

class _EmojiButton extends StatefulWidget {
  final String emojiKey;
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({
    required this.emojiKey,
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Semantics(
        button: true,
        label: emojiSemanticsLabel(context, widget.emojiKey),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AnimationUtils.getDuration(
              context,
              AppDimensions.animationDurationFast,
            ),
            padding: AppDimensions.paddingAll8,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: ExcludeSemantics(
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
