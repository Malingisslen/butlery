// lib/widgets/messaging/typing_indicator_container.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Styled container for typing indicator
class TypingIndicatorContainer extends StatelessWidget {
  final List<String> typingUsers;

  const TypingIndicatorContainer({
    super.key,
    required this.typingUsers,
  });

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      color: AppColors.backgroundBeige,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textMedium),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            '${typingUsers.join(', ')} skriver...',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMedium,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}