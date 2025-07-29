// lib/widgets/messaging/message_input_field.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Styled text input field for messages
class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback? onSubmitted;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundBeige,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: 5,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMedium,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
        ),
        onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
      ),
    );
  }
}