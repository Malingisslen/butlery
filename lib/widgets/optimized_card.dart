// lib/widgets/optimized_card.dart

import 'package:flutter/material.dart';

/// Wrapper som använder RepaintBoundary för att optimera rendering
class OptimizedCard extends StatelessWidget {
  final Widget child;

  const OptimizedCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}
