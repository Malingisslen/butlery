// lib/widgets/user/user_layout_widgets.dart
// Composite layouts and individual text components for user display

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/widgets/user/user_avatar_widgets.dart';

/// Layout widgets and text components for user display
class UserLayoutWidgets {
  /// Optimerad user name
  static Widget userName({
    required String displayName,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) => Text(
    displayName,
    style: style ?? AppTextStyles.titleMedium,
    maxLines: maxLines,
    overflow: overflow ?? TextOverflow.ellipsis,
  );

  /// Optimerad user email
  static Widget userEmail({
    required String email,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) => Text(
    email,
    style: style ?? AppTextStyles.titleMedium,
    maxLines: maxLines,
    overflow: overflow ?? TextOverflow.ellipsis,
  );

  /// Kombinerad user info
  static Widget userInfo({
    required String displayName,
    String? email,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    TextStyle? nameStyle,
    TextStyle? emailStyle,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        userName(displayName: displayName, style: nameStyle),
        if (email != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          userEmail(email: email, style: emailStyle),
        ],
      ],
    );
  }

  /// Optimerad user row
  static Widget userRow({
    String? imageUrl,
    required String displayName,
    String? email,
    String? subtitle,
    ImageSize avatarSize = ImageSize.medium,
    VoidCallback? onTap,
    Widget? trailing,
    bool showStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
  }) {
    return Semantics(
      label: displayName,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
          child: Row(
            children: [
              UserAvatarWidgets.avatar(
                imageUrl: imageUrl,
                displayName: displayName,
                size: avatarSize,
                showStatus: showStatus,
                isOnline: isOnline,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    userName(displayName: displayName),
                    if (email != null) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      userEmail(email: email),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppDimensions.spacingM),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Optimerad user card
  static Widget userCard({
    String? imageUrl,
    required String displayName,
    String? email,
    String? subtitle,
    String? description,
    ImageSize avatarSize = ImageSize.large,
    VoidCallback? onTap,
    Widget? actions,
    bool showStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return Card(
      margin: margin ?? const EdgeInsets.all(AppDimensions.paddingL),
      elevation: AppDimensions.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      child: Semantics(
        label: displayName,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatarWidgets.avatar(
                      imageUrl: imageUrl,
                      displayName: displayName,
                      size: avatarSize,
                      showStatus: showStatus,
                      isOnline: isOnline,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: userInfo(displayName: displayName, email: email),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(subtitle, style: AppTextStyles.titleMedium),
                ],
                if (description != null) ...[
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(description, style: AppTextStyles.bodyLarge),
                ],
                if (actions != null) ...[
                  const SizedBox(height: AppDimensions.spacingXl),
                  actions,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
