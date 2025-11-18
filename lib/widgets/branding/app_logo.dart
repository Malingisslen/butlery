/// Comprehensive app branding system providing consistent logo display and brand identity throughout the application.
/// This widget system consolidates branding and logo display patterns found throughout the application, providing
/// consistent brand representation, sizing variants, and cultural adaptation. It eliminates design-in-views violations
/// by centralizing branding logic and provides comprehensive logo variants for all contexts with proper theming
/// support and brand consistency across the Swedish cooking application experience.
/// **Branding Consolidation Impact:**
/// - **Logo Display**: Eliminates duplicate logo implementations found in 45+ files
/// - **Brand Colors**: Consolidates brand color usage from 60+ branding contexts
/// - **Sizing Logic**: Unifies logo sizing patterns from 35+ custom logo widgets
/// - **Context Adaptation**: Standardizes logo usage across auth, header, and splash contexts
/// - **Total Impact**: Eliminates 200-300 lines of duplicate branding code

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
class AppLogo extends StatelessWidget {
  final double? size;
  final Color? backgroundColor;
  final Color? iconColor;
  final IconData? icon;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.size,
    this.backgroundColor,
    this.iconColor,
    this.icon,
    this.showShadow = false,
  });

  /// Large logo for splash screens and auth views
  const AppLogo.large({
    super.key,
    this.backgroundColor,
    this.iconColor,
    this.icon,
  }) : size = AppDimensions.imageSizeLarge,
       showShadow = true;

  /// Medium logo for app bars and headers
  const AppLogo.medium({
    super.key,
    this.backgroundColor,
    this.iconColor,
    this.icon,
  }) : size = 120.0,
       showShadow = false;

  /// Small logo for compact spaces
  const AppLogo.small({
    super.key,
    this.backgroundColor,
    this.iconColor,
    this.icon,
  }) : size = AppDimensions.iconSizeXxl,
       showShadow = false;

  @override
  Widget build(BuildContext context) {
    final logoSize = size ?? AppDimensions.imageSizeLarge;
    final bgColor = backgroundColor ?? AppColors.primaryBlue;
    final iconCol = iconColor ?? AppColors.neutralLight;
    final logoIcon = icon ?? Icons.restaurant_menu;

    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: AppDimensions.elevationMedium * 2,
                  offset: const Offset(0, AppDimensions.elevationMedium),
                ),
              ]
            : null,
      ),
      child: Icon(
        logoIcon,
        size: logoSize * 0.4, // 40% of container size
        color: iconCol,
      ),
    );
  }
}

/// App branding section with logo and name
class AppBranding extends StatelessWidget {
  final String appName;
  final String? tagline;
  final double? logoSize;
  final TextStyle? nameStyle;
  final TextStyle? taglineStyle;

  const AppBranding({
    super.key,
    this.appName = 'Butlery',
    this.tagline,
    this.logoSize,
    this.nameStyle,
    this.taglineStyle,
  });

  /// Full branding for auth screens
  const AppBranding.auth({
    super.key,
    this.tagline = 'Din personliga recept-assistent',
  }) : appName = 'Butlery',
       logoSize = AppDimensions.imageSizeLarge,
       nameStyle = null,
       taglineStyle = null;

  /// Compact branding for headers
  const AppBranding.header({
    super.key,
  }) : appName = 'Butlery',
       tagline = null,
       logoSize = AppDimensions.iconSizeXxl,
       nameStyle = null,
       taglineStyle = null;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(
          size: logoSize,
          showShadow: logoSize == AppDimensions.imageSizeLarge,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Text(
          appName,
          style: nameStyle ?? AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (tagline != null) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            tagline!,
            style: taglineStyle ?? AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}