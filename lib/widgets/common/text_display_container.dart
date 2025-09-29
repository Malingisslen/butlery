// lib/widgets/common/text_display_container.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Container widget for displaying text content with consistent styling
class TextDisplayContainer extends StatelessWidget {
  final String text;
  final bool expanded;
  final bool scrollable;

  const TextDisplayContainer({
    super.key,
    required this.text,
    this.expanded = false,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium,
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    if (expanded) {
      content = Expanded(child: content);
    }

    return content;
  }
}