// lib/widgets/messaging/attachment_options_container.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Container for attachment options modal
class AttachmentOptionsContainer extends StatelessWidget {
  final List<AttachmentOption> options;

  const AttachmentOptionsContainer({
    super.key,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Dela innehåll',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options.map((option) => 
              AttachmentOptionButton(option: option)
            ).toList(),
          ),
          
          const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
    );
  }
}

/// Individual attachment option button
class AttachmentOptionButton extends StatelessWidget {
  final AttachmentOption option;

  const AttachmentOptionButton({
    super.key,
    required this.option,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: option.onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              option.icon,
              color: AppColors.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            option.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attachment option data model
class AttachmentOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}