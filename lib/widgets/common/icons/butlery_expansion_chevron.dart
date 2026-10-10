import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:flutter/material.dart';

/// The chevron of an [ExpansionTile], in the Butlery family.
///
/// The framework only lets a tile swap its trailing icon by dropping the
/// rotation that comes with the default one, so this widget brings the turn
/// back by following the tile's own controller. Pass it as `trailing`.
class ButleryExpansionChevron extends StatelessWidget {
  /// Creates the chevron. It must sit inside an [ExpansionTile].
  const ButleryExpansionChevron({super.key});

  static const Duration _turnDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final controller = ExpansibleController.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _turnDuration;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => AnimatedRotation(
        turns: controller.isExpanded ? 0.5 : 0,
        duration: duration,
        curve: Curves.easeIn,
        child: child,
      ),
      child: const ButleryIcon(ButleryIcons.chevronDown),
    );
  }
}
