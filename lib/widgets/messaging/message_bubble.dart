// lib/widgets/messaging/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/widgets/messaging/builders/message_content_builder.dart';
import 'package:butlery/widgets/messaging/components/message_status_widget.dart';
import 'package:butlery/widgets/messaging/components/system_message_widget.dart';

/// Message bubble component for chat messages.
/// Uses extracted components from [MessageContentBuilder],
/// [MessageStatusWidget], and [SystemMessageWidget].
class MessageBubble extends StatefulWidget {
  final Message message;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final Message? replyToMessage; // The message being replied to
  final bool showAvatar;
  final bool showTimestamp;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.onTap,
    this.onLongPress,
    this.onReply,
    this.replyToMessage,
    this.showAvatar = true,
    this.showTimestamp = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  double _dragExtent = 0;
  static const double _swipeThreshold = 80.0;
  static const double _maxSwipe = 120.0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (_reduceMotion) {
      _swipeController.duration = Duration.zero;
    } else {
      _swipeController.duration = const Duration(milliseconds: 200);
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  bool get _isFromCurrentUser =>
      widget.message.isFromCurrentUser(widget.currentUserId);
  bool get _isSystemMessage => widget.message.isSystemMessage;

  @override
  Widget build(BuildContext context) {
    if (_isSystemMessage) {
      return RepaintBoundary(child: _buildSystemMessage(context));
    }

    return RepaintBoundary(
      child: Semantics(
        label: 'Meddelande, svep för att svara',
        container: true,
        child: GestureDetector(
          onHorizontalDragUpdate:
              widget.onReply != null ? _handleDragUpdate : null,
          onHorizontalDragEnd: widget.onReply != null ? _handleDragEnd : null,
          child: AnimatedBuilder(
            animation: _swipeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: _swipeAnimation.value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingM,
                    vertical: AppDimensions.spacingXs,
                  ),
                  child: Stack(
                    alignment: _isFromCurrentUser
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    children: [
                      // Reply icon that appears during swipe
                      if (_dragExtent.abs() > 10)
                        Positioned(
                          left: _isFromCurrentUser ? 20 : null,
                          right: !_isFromCurrentUser ? 20 : null,
                          child: Opacity(
                            opacity: (_dragExtent.abs() / _swipeThreshold)
                                .clamp(0.0, 1.0),
                            child: const Icon(
                              Icons.reply,
                              color: AppColors.success,
                              size: 24,
                            ),
                          ),
                        ),
                      // Message content
                      Row(
                        mainAxisAlignment: _isFromCurrentUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!_isFromCurrentUser && widget.showAvatar) ...[
                            _buildAvatar(context),
                            const SizedBox(width: AppDimensions.paddingS),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: _isFromCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!_isFromCurrentUser && !widget.showAvatar)
                                  _buildSenderName(context),
                                _buildMessageCard(context),
                                if (widget.showTimestamp)
                                  _buildTimestamp(context),
                              ],
                            ),
                          ),
                          if (_isFromCurrentUser && widget.showAvatar) ...[
                            const SizedBox(width: AppDimensions.paddingS),
                            _buildAvatar(context),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.onReply == null) return;

    setState(() {
      // For received messages (left side), swipe right (positive delta)
      // For sent messages (right side), swipe left (negative delta)
      final delta = details.primaryDelta ?? 0;

      if (_isFromCurrentUser) {
        // Sent messages: swipe left
        _dragExtent = (delta < 0) ? delta.clamp(-_maxSwipe, 0) : 0;
      } else {
        // Received messages: swipe right
        _dragExtent = (delta > 0) ? delta.clamp(0, _maxSwipe) : 0;
      }
    });

    // Update animation
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(_dragExtent / 10, 0), // Reduced movement for better feel
    ).animate(_swipeController);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.onReply == null) return;

    // Trigger reply if threshold was met
    if (_dragExtent.abs() >= _swipeThreshold) {
      widget.onReply?.call();
    }

    // Reset animation
    setState(() {
      _dragExtent = 0;
    });
    _swipeAnimation = Tween<Offset>(
      begin: _swipeAnimation.value,
      end: Offset.zero,
    ).animate(_swipeController);
    _swipeController.forward(from: 0);
  }

  Widget _buildSystemMessage(BuildContext context) {
    return SystemMessageWidget(content: widget.message.content);
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: 0.2),
      ),
      child: widget.message.senderAvatarUrl != null
          ? SimpleImageWidget(
              imageUrl: widget.message.senderAvatarUrl!,
              config: ImageConfig.avatar(
                size: ImageSize.small,
              ),
              placeholder: _buildAvatarFallback(),
            )
          : _buildAvatarFallback(),
    );
  }

  Widget _buildAvatarFallback() {
    return Center(
      child: Text(
        widget.message.senderDisplayName.isNotEmpty
            ? widget.message.senderDisplayName[0].toUpperCase()
            : '?',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildSenderName(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.paddingS,
        bottom: AppDimensions.spacingXs,
      ),
      child: Text(
        widget.message.senderDisplayName,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textMedium,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context) {
    return Semantics(
      label: 'Meddelandeinnehåll, långtryck för alternativ',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: StyledCard(
          backgroundColor:
              _isFromCurrentUser ? AppColors.primaryBlue : AppColors.cardWhite,
          borderRadius: AppDimensions.borderRadiusM,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message.isReply && widget.replyToMessage != null)
                _buildReplyPreview(context),
              _buildMessageContent(context),
              if (_isFromCurrentUser) _buildMessageStatus(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final replyTo = widget.replyToMessage;
    if (replyTo == null) return const SizedBox.shrink();

    return ReplyPreviewWidget(
      senderName: replyTo.senderDisplayName,
      content: replyTo.displayContent,
      isFromCurrentUser: _isFromCurrentUser,
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    return MessageContentBuilder.build(
      context: context,
      message: widget.message,
      isFromCurrentUser: _isFromCurrentUser,
    );
  }

  Widget _buildMessageStatus(BuildContext context) {
    return MessageStatusWidget(status: widget.message.status);
  }

  Widget _buildTimestamp(BuildContext context) {
    return MessageTimestampWidget(
      timestamp: widget.message.sentAt,
      isFromCurrentUser: _isFromCurrentUser,
    );
  }
}
