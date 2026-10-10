// lib/widgets/user/user_layout_widgets.dart
// Composite layouts and individual text components for user display

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

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
}
