// lib/widgets/messaging/pending_image_bubble.dart
//
// BUT-2294: a chat image whose picture has not arrived. The sender sees their
// own copy of it while it waits for a connection; the others see that an
// image is on its way, and after [kPendingImageGiveUp] that it never came.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// After this long a placeholder the sender's phone no longer holds a picture
/// for is shown as never having arrived.
const Duration kPendingImageGiveUp = Duration(hours: 48);

class PendingImageBubble extends StatefulWidget {
  const PendingImageBubble({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.localCopy,
  });

  final Message message;
  final bool isFromCurrentUser;

  /// Finds the sender's copy of the picture; null reads it from the offline
  /// queue.
  final Future<String?> Function(String messageId, String userId)? localCopy;

  @override
  State<PendingImageBubble> createState() => _PendingImageBubbleState();
}

class _PendingImageBubbleState extends State<PendingImageBubble> {
  late final Future<String?> _copy = _findCopy();

  bool get _gaveUp =>
      clock.now().difference(widget.message.sentAt) > kPendingImageGiveUp;

  Future<String?> _findCopy() async {
    if (!widget.isFromCurrentUser) return null;
    try {
      final find = widget.localCopy ?? _fromQueue;
      return await find(widget.message.id, widget.message.senderId);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fromQueue(String messageId, String userId) async {
    final offline = ServiceLocator.tryGet<OfflineService>();
    if (offline == null || !offline.isQueueReady) return null;
    return offline.userStorage.chatImageCopyPath(messageId, userId);
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.isFromCurrentUser;
    // The sender's phone may still hold the picture after 48 hours, and then
    // the image is not lost, only slow.
    return FutureBuilder<String?>(
      future: _copy,
      builder: (context, snapshot) {
        final path = snapshot.data;
        final lost =
            _gaveUp &&
            (!mine ||
                (snapshot.connectionState == ConnectionState.done &&
                    path == null));
        return lost ? _neverArrived(context) : _waiting(context, path);
      },
    );
  }

  Widget _neverArrived(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      context.l10n.messagingImageNeverArrived,
      style: AppTextStyles.bodyMedium.copyWith(
        color: widget.isFromCurrentUser ? cs.onPrimary : cs.onSurface,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _waiting(BuildContext context, String? path) {
    final cs = Theme.of(context).colorScheme;
    final mine = widget.isFromCurrentUser;
    final textColor = mine
        ? AppModeColors.textSecondaryOnInk()
        : cs.onSurfaceVariant;
    final l10n = context.l10n;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: AppDimensions.messageAttachmentMaxWidth,
        maxHeight: 300,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        child: Container(
          height: 150,
          color: mine ? AppModeColors.surfaceRaisedOnInk() : cs.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null)
                Opacity(
                  opacity: 0.5,
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Center(
                child: Text(
                  mine
                      ? l10n.messagingImageWaitingToSend
                      : l10n.messagingImagePending,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
