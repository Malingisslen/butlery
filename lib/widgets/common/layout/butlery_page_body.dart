// lib/widgets/common/layout/butlery_page_body.dart
//
// The page column (BUT-2368): how wide a page's content may grow and where
// it stands on a wide screen. Pages use this instead of their own
// Center + ConstrainedBox, so a width is changed in one place.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';

export 'package:butlery/core/responsive/breakpoints.dart' show PageWidth;

class ButleryPageBody extends StatelessWidget {
  const ButleryPageBody({
    required this.child,
    this.width = PageWidth.text,
    super.key,
  });

  final Widget child;
  final PageWidth width;

  /// The page's side margin as padding: tokens.json space.layoutMargin, 20
  /// under 360 dp and 24 from there. Put it on the scrolling list rather
  /// than around it, so the scrollbar stays at the edge.
  static EdgeInsetsDirectional margin(
    BuildContext context, {
    double top = 0,
    double bottom = 0,
  }) {
    final side = AppDimensions.layoutMarginOf(context);
    return EdgeInsetsDirectional.fromSTEB(side, top, side, bottom);
  }

  @override
  Widget build(BuildContext context) {
    // Start-aligned, as Mer's pages are: on a wide screen the column stays
    // under the top bar's title instead of floating in the middle.
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Breakpoints.pageMaxWidth(context, width),
        ),
        child: child,
      ),
    );
  }
}
