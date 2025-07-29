// lib/widgets/messaging/chat_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

/// Styled app bar for chat view
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const ChatAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.cardWhite,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}