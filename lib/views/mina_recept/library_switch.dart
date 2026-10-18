import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';

/// "Alla recept | Kokböcker" at the top of Hem's library (BUT-1325). The
/// cookbooks are their own tab in Malin's decision; the library is the
/// lower half of Hem, so the tab is this switch rather than a navigation
/// item.
class LibrarySwitch extends StatelessWidget {
  const LibrarySwitch({
    required this.showCookbooks,
    required this.onChanged,
    super.key,
  });

  final bool showCookbooks;
  final ValueChanged<bool> onChanged;

  static const switchKey = ValueKey('library-switch');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final side = ButleryTopBar.sideMargin(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        0,
        side,
        0,
      ),
      child: UnderlineTabs<bool>(
        key: switchKey,
        values: const [false, true],
        labelOf: (showsCookbooks) => showsCookbooks
            ? l10n.libraryTabCookbooks
            : l10n.libraryTabAllRecipes,
        selected: showCookbooks,
        onChanged: onChanged,
      ),
    );
  }
}
