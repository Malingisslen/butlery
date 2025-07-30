// lib/widgets/common/layout/auth_form_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable authentication form card component
/// 
/// Provides consistent styling for login/signup forms following design separation principles.
/// This widget encapsulates the visual presentation while keeping business logic in the view.
class AuthFormCard extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const AuthFormCard({
    super.key,
    required this.child,
    this.maxWidth = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 400),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: child,
          ),
        ),
      ),
    );
  }
}