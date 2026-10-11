// lib/widgets/common/sheets/butlery_sheet.dart
//
// The one way a bottom sheet opens (BUT-2373). Komponentark §09 locks every
// sheet to the same frame: 12 px top edge, a handle in border-control, a
// sharp bottom edge, no shadow. The frame lives in the theme
// (NavigationThemes.bottomSheetTheme), so this helper takes no shape or
// colour; test/architecture/bottom_sheet_helper_test.dart keeps raw
// showModalBottomSheet calls out of lib/.
library;

import 'package:flutter/material.dart';

/// Opens [builder] in a bottom sheet with the handle on.
///
/// The sheet may grow with its content up to the screen height inside the
/// safe area, so [builder] returns content that sizes itself: a
/// `Column(mainAxisSize: MainAxisSize.min)`, a shrink-wrapped list, or a
/// `DraggableScrollableSheet`. [maxHeightFraction] caps a sheet whose content
/// would otherwise fill the screen.
Future<T?> showButlerySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  double? maxHeightFraction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    // A height cap keeps the theme's width cap.
    constraints: maxHeightFraction == null
        ? null
        : (Theme.of(context).bottomSheetTheme.constraints ??
                  const BoxConstraints())
              .copyWith(
                maxHeight:
                    MediaQuery.sizeOf(context).height * maxHeightFraction,
              ),
    builder: builder,
  );
}
