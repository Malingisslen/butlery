// lib/widgets/messaging/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/messaging/builders/message_content_builder.dart';
import 'package:butlery/widgets/messaging/components/message_status_widget.dart';
import 'package:butlery/widgets/messaging/components/system_message_widget.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';

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
  final void Function(String emoji)? onReactionToggle;
  final void Function(String optionId)? onPollVote;
  final VoidCallback? onPollClose;

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
    this.onReactionToggle,
    this.onPollVote,
    this.onPollClose,
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
  bool _showReactionPicker = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationDurationMedium,
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
      _swipeController.duration = AppDimensions.animationDurationMedium;
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
        label: context.l10n.a11yMessageSwipeToReply,
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
                            child: Icon(
                              Icons.reply,
                              color: context.butleryColors.success,
                              size: AppDimensions.iconSizeL,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.secondary.withValues(alpha: AppDimensions.opacityLight),
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
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSenderName(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.paddingS,
        bottom: AppDimensions.spacingXs,
      ),
      child: Text(
        widget.message.senderDisplayName,
        style: AppTextStyles.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context) {
    return Column(
      crossAxisAlignment: _isFromCurrentUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Reaction picker overlay
        if (_showReactionPicker && widget.onReactionToggle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
            child: EmojiReactionPicker(
              onReactionSelected: (emoji) {
                widget.onReactionToggle?.call(emoji);
                setState(() => _showReactionPicker = false);
              },
            ),
          ),

        Semantics(
          label: context.l10n.a11yMessageLongPressOptions,
          button: true,
          child: GestureDetector(
            onTap: () {
              if (_showReactionPicker) {
                setState(() => _showReactionPicker = false);
              } else {
                widget.onTap?.call();
              }
            },
            onLongPress: () {
              // Show reaction picker on long press if handler is available
              if (widget.onReactionToggle != null) {
                setState(() => _showReactionPicker = !_showReactionPicker);
              }
              widget.onLongPress?.call();
            },
            child: _buildBubble(context),
          ),
        ),

        // Reaction display below the bubble
        if (widget.message.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXxs),
            child: EmojiReactionDisplay(
              reactions: widget.message.reactions,
              currentUserId: widget.currentUserId,
              onReactionTap: (emoji) => widget.onReactionToggle?.call(emoji),
            ),
          ),
      ],
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
      currentUserId: widget.currentUserId,
      onPollVote: widget.onPollVote,
      onPollClose: widget.onPollClose,
    );
  }

  Widget _buildMessageStatus(BuildContext context) {
    return MessageStatusWidget(status: widget.message.status);
  }

  /// The chat bubble itself, wrapped in [HoverableCard] so it gains a subtle
  /// hover affordance on web/desktop when interactive. The rest
  /// decoration reproduces the previous [StyledCard] exactly — a flat filled
  /// square with no shadow — so there's no visual change at rest.
  Widget _buildBubble(BuildContext context) {
    final restDecoration = BoxDecoration(
      color: _isFromCurrentUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    );
    return HoverableCard(
      restDecoration: restDecoration,
      // Only imply clickability when the bubble actually does something on tap
      // (own tap handler, long-press, or a reaction toggle). A display-only
      // bubble defers the cursor, matching FriendCard/ShoppingListCard.
      enabled: widget.onTap != null ||
          widget.onLongPress != null ||
          widget.onReactionToggle != null,
      // Subtle shadow on hover (web/desktop) — fill + square corners unchanged.
      hoverDecoration: restDecoration.copyWith(boxShadow: AppShadows.subtle),
      child: Padding(
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
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    return MessageTimestampWidget(
      timestamp: widget.message.sentAt,
      isFromCurrentUser: _isFromCurrentUser,
    );
  }
}
