/// Custom header widget with forest green background and rust accent bar.
///
/// Provides a consistent header style across the app with:
/// - Forest green background
/// - Rust-colored bottom accent bar
/// - Josefin Sans lowercase typography
/// - Support for leading/trailing actions and search

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Header widget with forest green background and rust accent.
///
/// Use this instead of AppBar for views that need the new Butlery design.
///
/// Example:
/// ```dart
/// ButleryHeader(
///   title: 'mina recept',
///   trailing: IconButton(
///     icon: Icon(Icons.search),
///     onPressed: () {},
///   ),
/// )
/// ```
class ButleryHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a Butlery-styled header.
  const ButleryHeader({
    required this.title,
    this.leading,
    this.trailing,
    this.showAccentBar = true,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.onTitleTap,
    this.bottom,
    super.key,
  });

  /// The title text displayed in the header.
  /// Will be displayed in lowercase Josefin Sans.
  final String title;

  /// Widget to display before the title (usually a back button).
  final Widget? leading;

  /// Widget(s) to display after the title.
  final Widget? trailing;

  /// Whether to show the rust-colored accent bar at the bottom.
  final bool showAccentBar;

  /// Whether to center the title.
  final bool centerTitle;

  /// Whether to automatically add a back button when there's a route to pop.
  final bool automaticallyImplyLeading;

  /// Callback when the title is tapped.
  final VoidCallback? onTitleTap;

  /// Widget to display at the bottom of the header (e.g., TabBar).
  final PreferredSizeWidget? bottom;

  /// Height of the accent bar at the bottom.
  static const double accentBarHeight = 3.0;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(
      kToolbarHeight + (showAccentBar ? accentBarHeight : 0) + bottomHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showLeading =
        leading != null || (automaticallyImplyLeading && canPop);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: cs.primary,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: [
                      // Leading widget or back button
                      if (showLeading) ...[
                        leading ??
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: cs.onPrimary,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: context.l10n.commonBack,
                            ),
                      ] else ...[
                        const SizedBox(width: AppDimensions.spacingMd),
                      ],

                      // Title
                      Expanded(
                        child: Semantics(
                          label: title,
                          button: true,
                          child: GestureDetector(
                            onTap: onTitleTap,
                            behavior: HitTestBehavior.opaque,
                            child: centerTitle
                                ? Center(child: _buildTitle())
                                : _buildTitle(),
                          ),
                        ),
                      ),

                      // Trailing widget
                      if (trailing != null) ...[
                        trailing!,
                      ] else ...[
                        const SizedBox(width: AppDimensions.spacingMd),
                      ],
                    ],
                  ),
                ),

                // Bottom widget (e.g., TabBar)
                ?bottom,
              ],
            ),
          ),
        ),

        // Rust accent bar
        if (showAccentBar)
          ColoredBox(
            color: cs.secondary,
            child: const SizedBox(
              height: accentBarHeight,
              width: double.infinity,
            ),
          ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      title.toLowerCase(),
      style: AppTextStyles.headerTitle,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A sliver version of [ButleryHeader] for use in CustomScrollView.
class SliverButleryHeader extends StatelessWidget {
  /// Creates a sliver Butlery header.
  const SliverButleryHeader({
    required this.title,
    this.leading,
    this.trailing,
    this.showAccentBar = true,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.floating = true,
    this.pinned = true,
    this.snap = false,
    this.onTitleTap,
    super.key,
  });

  /// The title text displayed in the header.
  final String title;

  /// Widget to display before the title.
  final Widget? leading;

  /// Widget(s) to display after the title.
  final Widget? trailing;

  /// Whether to show the rust accent bar.
  final bool showAccentBar;

  /// Whether to center the title.
  final bool centerTitle;

  /// Whether to automatically add a back button.
  final bool automaticallyImplyLeading;

  /// Whether the header floats over content.
  final bool floating;

  /// Whether the header stays pinned at the top.
  final bool pinned;

  /// Whether the header snaps into view.
  final bool snap;

  /// Callback when the title is tapped.
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // BUT-706: stays a Material SliverAppBar (not AdaptiveAppBar) — its tappable
    // custom-widget title plus pinned/floating/snap collapse have no
    // CupertinoSliverNavigationBar equivalent. AdaptiveAppBar covers the
    // non-sliver bars; collapsing headers like this remain Material by design.
    return SliverAppBar(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      title: Semantics(
        label: title,
        button: true,
        child: GestureDetector(
          onTap: onTitleTap,
          child: Text(
            title.toLowerCase(),
            style: AppTextStyles.headerTitle,
          ),
        ),
      ),
      leading: leading,
      actions: trailing != null ? [trailing!] : null,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      floating: floating,
      pinned: pinned,
      snap: snap,
      elevation: 0,
      bottom: showAccentBar
          ? const PreferredSize(
              preferredSize: Size.fromHeight(ButleryHeader.accentBarHeight),
              child: _AccentBar(),
            )
          : null,
    );
  }
}

class _AccentBar extends StatelessWidget {
  const _AccentBar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.secondary,
      child: const SizedBox(
        height: ButleryHeader.accentBarHeight,
        width: double.infinity,
      ),
    );
  }
}
