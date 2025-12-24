// lib/widgets/messaging/components/message_status_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Widget displaying message delivery status.
class MessageStatusWidget extends StatelessWidget {
  final MessageStatus status;

  const MessageStatusWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: AppDimensions.iconSizeXs,
            color: AppColors.cardWhite.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppDimensions.spacingXxs),
          Text(
            _getStatusText(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.cardWhite.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  String _getStatusText() {
    switch (status) {
      case MessageStatus.sending:
        return 'Skickar';
      case MessageStatus.sent:
        return 'Skickat';
      case MessageStatus.delivered:
        return 'Levererat';
      case MessageStatus.read:
        return 'Last';
      case MessageStatus.failed:
        return 'Misslyckades';
    }
  }
}

/// Formats message timestamps into relative time strings.
class MessageTimeFormatter {
  MessageTimeFormatter._();

  /// Format timestamp to relative time string.
  static String format(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

/// Widget displaying message timestamp.
class MessageTimestampWidget extends StatelessWidget {
  final DateTime timestamp;
  final bool isFromCurrentUser;

  const MessageTimestampWidget({
    super.key,
    required this.timestamp,
    required this.isFromCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppDimensions.spacingXs,
        left: isFromCurrentUser ? 0 : AppDimensions.paddingS,
        right: isFromCurrentUser ? AppDimensions.paddingS : 0,
      ),
      child: Text(
        MessageTimeFormatter.format(timestamp),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textLight,
          fontSize: 10,
        ),
      ),
    );
  }
}
