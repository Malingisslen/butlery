// lib/widgets/messaging/typing_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Animated typing indicator widget for showing when users are typing
/// 
/// Displays a visual typing indicator with:
/// - Animated dots to show activity
/// - User names who are currently typing
/// - Proper Swedish localization
/// - Smooth fade in/out animations
class TypingIndicator extends StatefulWidget {
  final List<String> typingUserNames;
  final Duration animationDuration;

  const TypingIndicator({
    super.key,
    required this.typingUserNames,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.typingUserNames.isNotEmpty) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.typingUserNames.isNotEmpty && oldWidget.typingUserNames.isEmpty) {
      _animationController.forward();
    } else if (widget.typingUserNames.isEmpty && oldWidget.typingUserNames.isNotEmpty) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUserNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        color: AppColors.backgroundBeige,
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.more_horiz,
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeS,
                ),
              ),
            ),
            
            const SizedBox(width: AppDimensions.paddingS),
            
            // Typing indicator bubble
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textLight.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTypingText(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMedium,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  _buildAnimatedDots(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDot(0),
          _buildDot(1),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Create a staggered animation for each dot
        final progress = (_animationController.value * 3 - index).clamp(0.0, 1.0);
        final opacity = (Curves.easeInOut.transform(progress) * 0.8 + 0.2);
        
        return Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textMedium.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  String _getTypingText() {
    if (widget.typingUserNames.isEmpty) {
      return '';
    } else if (widget.typingUserNames.length == 1) {
      return '${widget.typingUserNames.first} skriver';
    } else if (widget.typingUserNames.length == 2) {
      return '${widget.typingUserNames.join(' och ')} skriver';
    } else {
      return '${widget.typingUserNames.take(2).join(', ')} och ${widget.typingUserNames.length - 2} andra skriver';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}