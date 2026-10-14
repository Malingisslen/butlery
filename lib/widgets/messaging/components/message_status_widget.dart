// lib/widgets/messaging/components/message_status_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Widget displaying message delivery status.
class MessageStatusWidget extends StatelessWidget {
  final MessageStatus status;

  const MessageStatusWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButleryIcon(
            _getStatusIcon(),
            size: AppDimensions.iconSizeXs,
            color: AppModeColors.textSecondaryOnInk(),
          ),
          const SizedBox(width: AppDimensions.space4),
          Text(
            _getStatusText(context),
            style: AppTextStyles.textXs.copyWith(
              color: AppModeColors.textSecondaryOnInk(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case MessageStatus.sending:
        return ButleryIcons.clock;
      case MessageStatus.sent:
        return ButleryIcons.check;
      case MessageStatus.delivered:
        return ButleryIcons.checkCheck;
      case MessageStatus.read:
        return ButleryIcons.checkCheck;
      case MessageStatus.failed:
        return ButleryIcons.triangleAlert;
    }
  }

  String _getStatusText(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return context.l10n.messagingSending;
      case MessageStatus.sent:
        return context.l10n.messagingSent;
      case MessageStatus.delivered:
        return context.l10n.messagingDelivered;
      case MessageStatus.read:
        return context.l10n.messagingRead;
      case MessageStatus.failed:
        return context.l10n.messagingFailed;
    }
  }
}

/// Formats message timestamps into relative time strings, as a date once
/// they are older than a week.
class MessageTimeFormatter {
  MessageTimeFormatter._();

  static String format(DateTime timestamp, {String? localeName}) =>
      ContextualTimeFormatter.compact(timestamp, localeName: localeName);
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: AppDimensions.space4,
        start: isFromCurrentUser ? 0 : AppDimensions.space8,
        end: isFromCurrentUser ? AppDimensions.space8 : 0,
      ),
      child: Text(
        MessageTimeFormatter.format(
          timestamp,
          localeName: Localizations.localeOf(context).toString(),
        ),
        style: AppTextStyles.textXs.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
