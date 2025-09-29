// lib/widgets/common/content_cards/text_display_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Reusable text display card component
/// 
/// Provides consistent styling for displaying text content in a card format.
/// Used for OCR results, previews, and other text content displays.
class TextDisplayCard extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsets? padding;
  final bool scrollable;

  const TextDisplayCard({
    super.key,
    required this.text,
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget textWidget = Text(
      text,
      style: textStyle ?? AppTextStyles.bodyMedium,
    );

    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: borderColor ?? AppColors.divider),
      ),
      child: scrollable 
        ? SingleChildScrollView(child: textWidget)
        : textWidget,
    );
  }
}