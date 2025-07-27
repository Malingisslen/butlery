// lib/widgets/branding/app_logo.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';

/// App logo widget with consistent branding
/// Eliminates design-in-views violations for logo display
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
        const SizedBox(height: AppDimensions.spacing16),
        Text(
          appName,
          style: nameStyle ?? Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (tagline != null) ...[
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            tagline!,
            style: taglineStyle ?? Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}