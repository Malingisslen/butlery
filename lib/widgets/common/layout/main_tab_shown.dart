// lib/widgets/common/layout/main_tab_shown.dart

import 'package:flutter/widgets.dart';

/// Whether the main tab around a widget is the one on screen. The shell keeps
/// every tab built (BUT-188), so a tab cannot tell from being built that the
/// user is looking at it.
class MainTabShown extends InheritedWidget {
  const MainTabShown({super.key, required this.shown, required super.child});

  final bool shown;

  /// True outside the shell: a page pushed on its own is on screen.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainTabShown>()?.shown ?? true;

  @override
  bool updateShouldNotify(MainTabShown oldWidget) => shown != oldWidget.shown;
}
