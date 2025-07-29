// lib/widgets/messaging/search_bar_container.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Styled container for search bar in conversations view
class SearchBarContainer extends StatelessWidget {
  final Widget child;

  const SearchBarContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      color: AppColors.backgroundBeige,
      child: child,
    );
  }
}