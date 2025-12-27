// lib/widgets/common/animations/animated_list_item.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';

/// A widget that animates its child with a fade-in and scale entrance effect.
///
/// Use this to add staggered entrance animations to list items.
/// Each item starts with opacity 0 and scale 0.95, then animates to
/// opacity 1 and scale 1.0 with a staggered delay based on the item index.
///
/// Respects reduced motion preferences via [AnimationUtils.shouldAnimate].
///
/// Example usage:
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, index) => AnimatedListItem(
///     index: index,
///     child: MyListTile(item: items[index]),
///   ),
/// );
/// ```
class AnimatedListItem extends StatefulWidget {
  /// The child widget to animate.
  final Widget child;

  /// The index of this item in the list.
  /// Used to calculate the stagger delay.
  final int index;

  /// Delay between each item's animation start.
  /// Default: 50ms per item.
  final Duration staggerDelay;

  /// Total duration of the entrance animation.
  /// Default: 400ms.
  final Duration duration;

  /// Animation curve.
  /// Default: Curves.easeOut.
  final Curve curve;

  /// Starting scale value.
  /// Default: 0.95 (5% smaller).
  final double startScale;

  /// Maximum stagger delay to prevent long waits on large lists.
  /// Items beyond this delay cap will all start at the same time.
  /// Default: 500ms (10 items at 50ms each).
  final Duration maxStaggerDelay;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOut,
    this.startScale = 0.95,
    this.maxStaggerDelay = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _scaleAnimation = Tween<double>(
      begin: widget.startScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    _startAnimation();
  }

  void _startAnimation() {
    if (_reduceMotion) {
      // Skip animation, show immediately
      _controller.value = 1.0;
      return;
    }

    // Calculate stagger delay with cap
    final staggerMs = widget.staggerDelay.inMilliseconds * widget.index;
    final cappedMs = staggerMs.clamp(0, widget.maxStaggerDelay.inMilliseconds);
    final delay = Duration(milliseconds: cappedMs);

    // Start animation after stagger delay
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A builder that creates an animated list with staggered entrance animations.
///
/// This is a convenience wrapper around [ListView.builder] that automatically
/// wraps each item with [AnimatedListItem].
///
/// Example usage:
/// ```dart
/// AnimatedListBuilder(
///   itemCount: recipes.length,
///   itemBuilder: (context, index) => RecipeCard(recipe: recipes[index]),
/// );
/// ```
class AnimatedListBuilder extends StatelessWidget {
  /// The number of items in the list.
  final int itemCount;

  /// Builder function for each list item.
  final IndexedWidgetBuilder itemBuilder;

  /// Optional padding for the list.
  final EdgeInsetsGeometry? padding;

  /// Optional scroll controller.
  final ScrollController? controller;

  /// Whether the list should shrink-wrap.
  final bool shrinkWrap;

  /// The scroll physics for the list.
  final ScrollPhysics? physics;

  /// Delay between each item's animation start.
  final Duration staggerDelay;

  /// Total duration of each item's entrance animation.
  final Duration duration;

  const AnimatedListBuilder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          index: index,
          staggerDelay: staggerDelay,
          duration: duration,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}
