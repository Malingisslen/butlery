// lib/widgets/common/layout/layout_scaffolds.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/indicators/notification_badge.dart';

/// Layout scaffold components for main navigation and simple layouts
///
/// This module provides the core layout structures including
/// main menu with bottom navigation and simple layout for detail views.
class LayoutScaffolds {
  /// Main layout with bottom navigation and app bar
  /// Exactly like original MainLayoutMenu with ALL functionality preserved
  static Widget mainMenu({
    required Widget body,
    int? currentIndex,
    String? title,
    List<Widget>? actions,
    Widget? floatingActionButton,
  }) {
    return _MainMenuLayout(
      body: body,
      currentIndex: currentIndex,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
    );
  }

  /// Simple layout without bottom navigation
  /// For detail views and dialogs
  static Widget simpleLayout({
    required Widget body,
    String? title,
    List<Widget>? actions,
    PreferredSizeWidget? appBar,
  }) {
    return _SimpleLayout(
      body: body,
      title: title,
      actions: actions,
      appBar: appBar,
    );
  }
}

/// Main menu layout with bottom navigation
class _MainMenuLayout extends StatefulWidget {
  final Widget body;
  final int? currentIndex;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const _MainMenuLayout({
    required this.body,
    this.currentIndex,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  State<_MainMenuLayout> createState() => _MainMenuLayoutState();
}

class _MainMenuLayoutState extends State<_MainMenuLayout> {
  int _unreadMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final messagingService = ServiceLocator.get<MessagingService>();
      final count = await messagingService.getUnreadConversationsCount();
      if (mounted) {
        setState(() {
          _unreadMessagesCount = count;
        });
      }
    } catch (e) {
      // Messaging service might not be available yet, that's okay
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.title != null
          ? AppBar(
              title: Text(
                widget.title!,
                style: AppTextStyles.headlineSmall,
              ),
              actions: widget.actions,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: AppColors.textDark,
              automaticallyImplyLeading: false,
            )
          : null,
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex ?? 0,
      onTap: (index) => _handleNavigation(context, index),
      type: BottomNavigationBarType.fixed, // Important for 5 items
      // Remove ALL custom styling - let theme handle everything
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          activeIcon: Icon(Icons.book),
          label: 'Mina recept',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.add_outlined),
          activeIcon: Icon(Icons.add),
          label: 'Lägg till',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'Veckomeny',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart),
          label: 'Inköpslista',
        ),
        BottomNavigationBarItem(
          icon: _buildMessagesIcon(false),
          activeIcon: _buildMessagesIcon(true),
          label: 'Meddelanden',
        ),
      ],
    );
  }

  Widget _buildMessagesIcon(bool isActive) {
    if (_unreadMessagesCount == 0) {
      return Icon(isActive ? Icons.message : Icons.message_outlined);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.message : Icons.message_outlined),
        Positioned(
          top: -4,
          right: -4,
          child: NotificationBadge(
            count: _unreadMessagesCount,
          ),
        ),
      ],
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // Check if we're already on that page
    if (widget.currentIndex == index) {
      return; // Do nothing if we're already on the page
    }

    String route;
    switch (index) {
      case 0:
        route = '/';
        break;
      case 1:
        route = '/laggTill';
        break;
      case 2:
        route = '/veckomeny';
        break;
      case 3:
        route = '/inkopslista';
        break;
      case 4:
        route = '/messages';
        break;
      default:
        return;
    }

    // Use pushReplacementNamed to avoid stacking up views
    Navigator.pushReplacementNamed(context, route);
  }
}

/// Simple layout for views without bottom navigation
class _SimpleLayout extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const _SimpleLayout({
    required this.body,
    this.title,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ??
          (title != null
              ? AppBar(
                  title: Text(
                    title!,
                    style: AppTextStyles.headlineSmall,
                  ),
                  actions: actions,
                )
              : null),
      body: body,
    );
  }
}