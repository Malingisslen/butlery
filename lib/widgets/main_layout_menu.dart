// lib/widgets/main_layout_menu.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MainLayoutMenu extends StatelessWidget {
  final Widget body;
  final int? currentIndex;
  final String? title;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;

  const MainLayoutMenu({
    super.key,
    required this.body,
    this.currentIndex,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(
                title!,
                style: AppTheme.sectionTitleStyle,
              ),
              actions: actions,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              automaticallyImplyLeading: false,
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return AppTheme.styledBottomNavBar(
      // ✅ AppTheme navigation
      currentIndex: currentIndex ?? 0,
      onTap: (index) => _handleNavigation(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          activeIcon: Icon(Icons.book),
          label: 'Mina recept',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_outlined),
          activeIcon: Icon(Icons.add),
          label: 'Lägg till',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'Veckomeny',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart),
          label: 'Inköpslista',
        ),
      ],
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // Kontrollera om vi redan är på den sidan
    if (currentIndex == index) {
      return; // Gör inget om vi redan är på sidan
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
      default:
        return;
    }

    // Använd pushReplacementNamed för att undvika att stacka upp vyer
    Navigator.pushReplacementNamed(context, route);
  }
}

/// Variant för vyer som inte ska ha bottom navigation
class SimpleLayout extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const SimpleLayout({
    super.key,
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
                    style: AppTheme.sectionTitleStyle,
                  ),
                  actions: actions,
                )
              : null),
      body: body,
    );
  }
}
