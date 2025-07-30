// lib/widgets/common/indicators/emoji_avatar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable emoji avatar component
/// 
/// Provides consistent styling for emoji-based avatars.
/// Used for group icons, user avatars with emojis, etc.
class EmojiAvatar extends StatelessWidget {
  final String emoji;
  final double? size;
  final Color? backgroundColor;
  final double? fontSize;

  const EmojiAvatar({
    super.key,
    required this.emoji,
    this.size,
    this.backgroundColor,
    this.fontSize,
  });

  /// Standard group avatar
  const EmojiAvatar.group({
    super.key,
    required this.emoji,
  }) : size = 48,
       backgroundColor = null,
       fontSize = 24;

  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? 48;
    final textSize = fontSize ?? 24;
    
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: textSize),
        ),
      ),
    );
  }
}