// lib/widgets/common/butlery_control_focus.dart
//
// Det delade greppet för små kontroller: kryssruta, reglage, radio, chip,
// flik, menypost och länk.
//
// Kanon:
// - Fokus är en 2 px ring 3 px utanför, ink på ljust och papper på mörkt,
//   aldrig saffran (tokens.json:155-160; Grafisk manual v6:209; Komponentark
//   v1:657).
// - Synligt mindre kontroller får en 48 dp-wrapper som finns i koden, och
//   fokusramen ritas runt hela wrappern, aldrig runt bara glyfen (Grafisk
//   manual v6:381; tokens.json:485-492 touchTarget).
// - Den frysta modellen kräver FOCUSED för checkbox, switch, radio, tab, link
//   och menuitem (fas2/block288-uxfrysning.json, interaktion
//   CSR::ROLE::<roll>::FOCUSED).
//
// Ringen bär fokus ensam. Därför tar greppet bort den fokuserade tonplattan
// (Theme.focusColor, som i dag är saffran, app_theme.dart:88, och
// komponentteman som lägger en overlay i fokuserat läge). Opacitet är aldrig
// ett tillstånd (tokens.json:40-53).

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// The shared grip for a small control: a box of at least 48 × 48 dp with
/// the canonical focus ring around the whole box, and no focus tint.
///
/// Wrap a checkbox, switch, radio, chip, bottom-navigation tab or link in
/// it. The ring follows focus anywhere inside [child] and shows only for
/// keyboard focus, like the ring on buttons.
///
/// The box is a hit target only where [child]'s own gesture detector fills
/// it. Material's checkbox, switch, radio and chips already take a padded
/// 48 dp target; a hand-built control puts its own [InkWell] around
/// [ButleryControlFocus.box] instead.
class ButleryControlFocus extends StatelessWidget {
  const ButleryControlFocus({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  /// The control.
  final Widget child;

  /// The wrapper's corner radius. The ring runs parallel to it.
  final BorderRadius borderRadius;

  /// The minimum hit target, tokens.json:485-492 (touchTarget.min).
  static const double minSize = AppDimensions.minTouchTarget;

  /// [child] at its own size, centred in a box of at least [minSize] ×
  /// [minSize]. For a hand-built control whose gesture detector should fill
  /// the 48 dp target while the visible control stays smaller.
  static Widget box({required Widget child}) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: minSize, minHeight: minSize),
    child: Align(widthFactor: 1, heightFactor: 1, child: child),
  );

  /// [base] with the focused state resolved to no tint. Every other state
  /// resolves as [base] does.
  static WidgetStateProperty<Color?> withoutFocusTint(
    WidgetStateProperty<Color?>? base,
  ) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused) &&
        !states.contains(WidgetState.pressed)) {
      return Colors.transparent;
    }
    return base?.resolve(states);
  });

  /// [theme] without the focus tints the small controls read: the ring
  /// replaces them.
  static ThemeData themeWithoutFocusTint(ThemeData theme) => theme.copyWith(
    focusColor: Colors.transparent,
    checkboxTheme: theme.checkboxTheme.copyWith(
      overlayColor: withoutFocusTint(theme.checkboxTheme.overlayColor),
    ),
    switchTheme: theme.switchTheme.copyWith(
      overlayColor: withoutFocusTint(theme.switchTheme.overlayColor),
    ),
    radioTheme: theme.radioTheme.copyWith(
      overlayColor: withoutFocusTint(theme.radioTheme.overlayColor),
    ),
    tabBarTheme: theme.tabBarTheme.copyWith(
      overlayColor: withoutFocusTint(theme.tabBarTheme.overlayColor),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: themeWithoutFocusTint(Theme.of(context)),
      child: ButleryFocusRing(
        borderRadius: borderRadius,
        // A minimum only: tight constraints from the parent (a tab in an
        // Expanded) still reach the control unchanged.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minSize,
            minHeight: minSize,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A focus ring that follows the focus node of the control *around* it.
///
/// Some controls build their own [InkWell] above the content the app
/// supplies: a [TabBar] tab, for instance. The content cannot wrap the
/// InkWell, so it listens to the nearest ancestor [Focus] instead, which is
/// the InkWell's own node, and draws the ring around itself.
///
/// Put it as the tab's child: `Tab(child: ButleryAncestorFocusRing(...))`,
/// or use [ButleryTab]. Pair the [TabBar] with
/// `overlayColor: ButleryControlFocus.withoutFocusTint(null)` so no tint is
/// drawn under the ring.
class ButleryAncestorFocusRing extends StatefulWidget {
  const ButleryAncestorFocusRing({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<ButleryAncestorFocusRing> createState() =>
      _ButleryAncestorFocusRingState();
}

class _ButleryAncestorFocusRingState extends State<ButleryAncestorFocusRing> {
  FocusNode? _node;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final node = Focus.maybeOf(context, scopeOk: false);
    if (!identical(node, _node)) {
      _node?.removeListener(_onFocus);
      _node = node?..addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _node?.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ButleryFocusRing(
      focused: _node?.hasFocus ?? false,
      borderRadius: widget.borderRadius,
      child: widget.child,
    );
  }
}

/// A [TabBar] tab whose label box is at least 48 dp tall and carries the
/// canonical focus ring when the tab has keyboard focus.
class ButleryTab extends StatelessWidget implements PreferredSizeWidget {
  const ButleryTab({this.text, this.icon, this.child, super.key})
    : assert(text != null || icon != null || child != null);

  final String? text;
  final Widget? icon;
  final Widget? child;

  @override
  Size get preferredSize => const Size.fromHeight(ButleryControlFocus.minSize);

  @override
  Widget build(BuildContext context) {
    return ButleryAncestorFocusRing(
      child: ButleryControlFocus.box(
        child: Tab(text: text, icon: icon, child: child),
      ),
    );
  }
}

/// A popup menu item with the canonical focus ring around the whole row and
/// no focus tint (Q-P4-16: the shared grip for menu items).
///
/// Use it wherever a [PopupMenuItem] would go. Its row is at least 48 dp
/// tall, as PopupMenuItem's already is (kMinInteractiveDimension).
class ButleryMenuItem<T> extends PopupMenuItem<T> {
  const ButleryMenuItem({
    required super.child,
    super.value,
    super.onTap,
    super.enabled,
    super.height,
    super.padding,
    super.textStyle,
    super.labelTextStyle,
    super.mouseCursor,
    super.key,
  });

  @override
  PopupMenuItemState<T, ButleryMenuItem<T>> createState() =>
      _ButleryMenuItemState<T>();
}

class _ButleryMenuItemState<T>
    extends PopupMenuItemState<T, ButleryMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ButleryControlFocus.themeWithoutFocusTint(Theme.of(context)),
      child: ButleryFocusRing(child: super.build(context)),
    );
  }
}
