// lib/views/hem/hem_library_scroll.dart
//
// HEM-HERO (package 6): Hem's greeting and tonight band above the recipe
// library, scrolling as one.
//
//   Skarmar v12 del 1 #hemrecept (:124-150): "hälsning + ikväll överst,
//       receptbiblioteket direkt under".
//
// The header sits in a NestedScrollView and the library in its body. The
// library's scrollable must attach to the PrimaryScrollController the
// NestedScrollView provides (primary: true, no controller of its own):
// that is what links the two, so scrolling the recipes first scrolls the
// header away and every recipe stays reachable. A large text size on a
// narrow phone makes the header tall, and it still leaves the screen.
//
// Interpretation: scrolling the library moves the header out; the search and
// filter row in the body stays (it is not part of Hem's header).
library;

import 'package:flutter/material.dart';

/// Hem's [header] above the library [body], scrolling as one.
class HemLibraryScroll extends StatelessWidget {
  const HemLibraryScroll({
    super.key,
    this.nestedKey,
    this.header,
    required this.body,
    this.onLibraryScrolled,
  });

  /// Reaches the NestedScrollView's inner controller, to restore the
  /// library's offset (BUT-1028).
  final GlobalKey<NestedScrollViewState>? nestedKey;

  /// Hem's greeting and tonight band. Null when Hem is not shown (selection
  /// mode).
  final Widget? header;

  /// The library. Its vertical scrollable must be `primary` and have no
  /// controller of its own.
  final Widget body;

  /// The library's own scroll offset, on every vertical scroll of it
  /// (BUT-1028 persistence).
  final ValueChanged<double>? onLibraryScrolled;

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    return NestedScrollView(
      key: nestedKey,
      headerSliverBuilder: (context, _) => [
        if (header != null) SliverToBoxAdapter(child: header),
      ],
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical) {
            onLibraryScrolled?.call(notification.metrics.pixels);
          }
          return false;
        },
        child: body,
      ),
    );
  }
}
