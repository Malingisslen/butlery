import 'package:flutter/material.dart';

/// Reports every touch on the app to [onActivity] for the session timeout,
/// without taking the touch from the screen below.
class SessionActivityDetector extends StatelessWidget {
  const SessionActivityDetector({
    required this.onActivity,
    required this.child,
    super.key,
  });

  final VoidCallback onActivity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActivity,
      onPanDown: (_) => onActivity(),
      onScaleStart: (_) => onActivity(),
      behavior: HitTestBehavior.translucent,
      // A tap action makes a screen-sized semantics node, and on the web that
      // node takes every click that lands where no control has a node of its
      // own, so a box drawn inside ExcludeSemantics never saw its tap.
      excludeFromSemantics: true,
      child: child,
    );
  }
}
