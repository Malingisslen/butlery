// lib/widgets/common/layout/layout_scaffolds.dart
//
// UI Redesign: Updated to use ButleryHeader and new navigation
// BUT-188: IndexedStack for tab state preservation

import 'package:flutter/material.dart';
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/views/unified_shopping_view.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_header.dart';
import 'package:butlery/widgets/common/pwa_install_banner.dart';
import 'package:butlery/core/keyboard/app_actions.dart'
    show mainTabSwitchRequest;

/// Layout scaffold components for main navigation and simple layouts
/// This module provides the core layout structures including
/// main menu with bottom navigation and simple layout for detail views.
class LayoutScaffolds {
  /// Main layout with bottom navigation and IndexedStack for tab persistence.
  ///
  /// [initialIndex] sets the tab shown on first build (e.g. from deep link).
  static Widget mainMenu({
    int? initialIndex,
    PreferredSizeWidget? appBar,
  }) {
    return _MainMenuLayout(
      initialIndex: initialIndex ?? 0,
      appBar: appBar,
    );
  }

  /// Simple layout for views without bottom navigation.
  /// For detail views and dialogs
  static Widget simpleLayout({
    required Widget body,
    String? title,
    List<Widget>? actions,
    PreferredSizeWidget? appBar,
    Widget? floatingActionButton,
    bool showBottomNav = false,
    int? bottomNavIndex,
  }) {
    return _SimpleLayout(
      body: body,
      title: title,
      actions: actions,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      showBottomNav: showBottomNav,
      bottomNavIndex: bottomNavIndex,
    );
  }
}

/// Main menu layout with IndexedStack preserving tab state across switches.
class _MainMenuLayout extends StatefulWidget {
  final int initialIndex;
  final PreferredSizeWidget? appBar;

  const _MainMenuLayout({
    required this.initialIndex,
    this.appBar,
  });

  @override
  State<_MainMenuLayout> createState() => _MainMenuLayoutState();
}

class _MainMenuLayoutState extends State<_MainMenuLayout> {
  late int _selectedIndex;

  /// Lazily built tab views — only created when first selected.
  final List<Widget?> _tabs = List.filled(3, null);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 2);
    // BUT-521: react to keyboard shortcut (Ctrl/Cmd+1-3) tab switches.
    mainTabSwitchRequest.addListener(_onTabSwitchRequest);
  }

  @override
  void dispose() {
    mainTabSwitchRequest.removeListener(_onTabSwitchRequest);
    super.dispose();
  }

  void _onTabSwitchRequest() {
    if (!mounted) return;
    final requested = mainTabSwitchRequest.value.clamp(0, 2);
    if (requested == _selectedIndex) return;
    setState(() => _selectedIndex = requested);
  }

  Widget _buildTab(int index) {
    _tabs[index] ??= switch (index) {
      0 => const MinaReceptView(),
      1 => const VeckomenyView(),
      2 => const UnifiedShoppingView(),
      _ => const SizedBox.shrink(),
    };
    return _tabs[index]!;
  }

  void _showAddRecipeModal(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Material drag handle — rounded exception to square design
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant
                      .withValues(alpha: AppDimensions.opacityMediumLight),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                context.l10n.addRecipeTitle,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingL),
              _buildModalGrid(context, modalContext, cs),
              const SizedBox(height: AppDimensions.spacingMd),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalGrid(
      BuildContext rootContext, BuildContext modalContext, ColorScheme cs) {
    const spacing = AppDimensions.spacingMd;

    void navigate(String route) {
      Navigator.of(modalContext).pop();
      Navigator.of(rootContext).pushNamed(route);
    }

    // Responsive sizing — mirrors LaggTillReceptView pattern
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonSize =
            ((constraints.maxWidth - spacing) / 2).clamp(120.0, 160.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modalButton(cs,
                    label: rootContext.l10n.recipeImportLink,
                    icon: Icons.link,
                    color: cs.secondary,
                    size: buttonSize,
                    onTap: () => navigate(Routes.smartImport)),
                const SizedBox(width: spacing),
                _modalButton(cs,
                    label: rootContext.l10n.recipeWriteManually,
                    icon: Icons.edit,
                    color: cs.primary,
                    size: buttonSize,
                    onTap: () => navigate(Routes.manualEntry)),
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modalButton(cs,
                    label: rootContext.l10n.recipeFromImage,
                    icon: Icons.image,
                    color: cs.primary,
                    size: buttonSize,
                    onTap: () => navigate(Routes.photoImport)),
                const SizedBox(width: spacing),
                _modalButton(cs,
                    label: rootContext.l10n.recipeFromArchive,
                    icon: Icons.archive,
                    color: cs.secondary,
                    size: buttonSize,
                    onTap: () => navigate(Routes.importFranArkiv)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _modalButton(
    ColorScheme cs, {
    required String label,
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Semantics(
          label: label,
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: AppDimensions.iconSizeXl, color: cs.onPrimary),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          // BUT-521: keep notifier in sync with local state so the next
          // shortcut to tab 0 isn't deduped as a no-op.
          mainTabSwitchRequest.value = 0;
        }
      },
      child: AdaptiveNavigationScaffold(
        currentIndex: _selectedIndex,
        items: ButleryAdaptiveNavigation.getNavigationItems(context),
        appBar: widget.appBar,
        onNavigationChanged: (index) {
          // "+" button opens modal instead of switching tabs
          if (index == 3) {
            _showAddRecipeModal(context);
            return;
          }
          setState(() => _selectedIndex = index);
          // BUT-521: keep notifier in sync with local state so a subsequent
          // Cmd/Ctrl+1-3 to the same index isn't deduped as a no-op.
          mainTabSwitchRequest.value = index;
        },
        body: Column(
          children: [
            // Self-hides on non-web (stub returns canPromptInstall=false)
            // and on web until the 3-session install-prompt heuristic fires.
            const PwaInstallBanner(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: List.generate(3, _buildTab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple layout for views without bottom navigation.
/// **UI Redesign:** Uses ButleryHeader for consistent styling.
class _SimpleLayout extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool showBottomNav;
  final int? bottomNavIndex;

  const _SimpleLayout({
    required this.body,
    this.title,
    this.actions,
    this.appBar,
    this.floatingActionButton,
    this.showBottomNav = false,
    this.bottomNavIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ??
          (title != null
              ? ButleryHeader(
                  title: title!,
                  trailing: actions != null && actions!.isNotEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        )
                      : null,
                )
              : null),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showBottomNav
          ? ButleryBottomNavigation(
              currentIndex: bottomNavIndex,
              items: ButleryAdaptiveNavigation.getNavigationItems(context),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              selectedItemColor: Theme.of(context).colorScheme.primaryContainer,
              unselectedItemColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: (index) {
                final route =
                    ButleryAdaptiveNavigation.getNavigationItems(context)[index]
                        .route;
                Navigator.pushNamed(context, route);
              },
            )
          : null,
    );
  }
}
