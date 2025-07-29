// lib/widgets/messaging/message_status_icon.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message_type.dart';
import 'package:butlery/theme/app_colors.dart';

/// Reusable message status icon widget
/// 
/// Displays appropriate icons for different message statuses:
/// - Sending: Clock icon with animation
/// - Sent: Single check mark
/// - Delivered: Double check mark
/// - Read: Double check mark with color change
/// - Failed: Error icon with red color
class MessageStatusIcon extends StatefulWidget {
  final MessageStatus status;
  final Color? color;
  final double size;
  final bool showAnimation;

  const MessageStatusIcon({
    super.key,
    required this.status,
    this.color,
    this.size = 12,
    this.showAnimation = true,
  });

  @override
  State<MessageStatusIcon> createState() => _MessageStatusIconState();
}

class _MessageStatusIconState extends State<MessageStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    if (widget.status == MessageStatus.sending && widget.showAnimation) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(MessageStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.status == MessageStatus.sending && widget.showAnimation) {
      if (!_animationController.isAnimating) {
        _animationController.repeat();
      }
    } else {
      _animationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _buildStatusIcon(),
    );
  }

  Widget _buildStatusIcon() {
    switch (widget.status) {
      case MessageStatus.sending:
        return widget.showAnimation
            ? AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) => Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Icon(
                    Icons.access_time,
                    size: widget.size,
                    color: widget.color ?? AppColors.textMedium,
                  ),
                ),
              )
            : Icon(
                Icons.access_time,
                size: widget.size,
                color: widget.color ?? AppColors.textMedium,
              );

      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: widget.size,
          color: widget.color ?? AppColors.textMedium,
        );

      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: widget.size,
          color: widget.color ?? AppColors.textMedium,
        );

      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: widget.size,
          color: widget.color ?? AppColors.primaryBlue,
        );

      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: widget.size,
          color: widget.color ?? AppColors.error,
        );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}