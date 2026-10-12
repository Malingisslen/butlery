import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_segment_switch.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

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

  /// Room a label needs beside it for the segment's padding and border.
  static const double segmentPadding = ButlerySegmentSwitch.segmentPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final side = ButleryTopBar.sideMargin(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        AppDimensions.space8,
        side,
        0,
      ),
      child: ButlerySegmentSwitch<bool>(
        key: switchKey,
        choices: [
          (false, l10n.libraryTabAllRecipes),
          (true, l10n.libraryTabCookbooks),
        ],
        selected: showCookbooks,
        onChanged: onChanged,
      ),
    );
  }
}
