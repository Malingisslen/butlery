// lib/widgets/messaging/styled_modal_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Styled modal bottom sheet for messaging dialogs
class StyledModalBottomSheet {
  /// Show a styled modal bottom sheet with consistent theming
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (context) => child,
    );
  }
}