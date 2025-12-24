// lib/widgets/common/share_dialog/share_message_input.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

class ShareMessageInput {
  static Widget build(
    BuildContext context,
    TextEditingController messageController,
    String? initialMessage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meddelande (valfritt)',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        TextField(
          controller: messageController,
          decoration: InputDecoration(
            hintText: 'Skriv ett meddelande...',
            hintStyle: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: AppDimensions.spacingXl),
      ],
    );
  }
}
