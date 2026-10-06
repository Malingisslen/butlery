// lib/core/keyboard/app_keyboard_layer.dart
//
// BUT-521: the app's keyboard layer. Shortcuts + Actions around the whole
// navigator subtree, so Esc / Cmd+K / Cmd+1-3 etc. work on every route.

import 'package:flutter/widgets.dart';

import 'package:butlery/core/keyboard/app_actions.dart';
import 'package:butlery/core/keyboard/app_shortcuts.dart';

/// The app's shortcuts and actions around [child].
class AppKeyboardLayer extends StatelessWidget {
  const AppKeyboardLayer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: AppShortcuts.bindings,
      child: Actions(
        actions: AppActions.dispatch(),
        // `Focus(autofocus)` makes the Shortcuts widget the focus root that
        // receives unhandled key events. It is the keyboard layer, not a
        // control: Tab skips it and the app-level focus ring
        // (ButleryAppFocusRing) does not draw around the screen (BUT-2148).
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      ),
    );
  }
}
