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
// filter row stays (it is not part of Hem's header). It is a pinned sliver
// under the header rather than part of the body: the body is only as tall as
// what the header leaves, which a large text size can bring to nearly nothing
// (BUT-2254).
library;

import 'package:flutter/material.dart';

/// Hem's [header] above the library [body], scrolling as one.
class HemLibraryScroll extends StatelessWidget {
  const HemLibraryScroll({
    super.key,
    this.nestedKey,
    this.header,
    this.pinned,
    required this.body,
    this.onLibraryScrolled,
  });

  /// Reaches the NestedScrollView's inner controller, to restore the
  /// library's offset (BUT-1028).
  final GlobalKey<NestedScrollViewState>? nestedKey;

  /// Hem's greeting and tonight band. Null when Hem is not shown (selection
  /// mode).
  final Widget? header;

  /// The library's own header (its title row, search and filters): it
  /// scrolls up with [header] and then stays at the top.
  final Widget? pinned;

  /// The library. Its vertical scrollable must be `primary` and have no
  /// controller of its own, and with a [pinned] header it must start with
  /// [overlapInjector] (see [sliverBody] and [boxBody]).
  final Widget body;

  /// The library's own scroll offset, on every vertical scroll of it
  /// (BUT-1028 persistence).
  final ValueChanged<double>? onLibraryScrolled;

  /// Takes the [pinned] header's height off the top of the body: a pinned
  /// sliver gives up its layout extent while it still paints, so without
  /// this the body's first row would sit under it. Only valid inside [body].
  static Widget overlapInjector(BuildContext context) => SliverOverlapInjector(
    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
  );

  /// A [body] made of [slivers]: one primary scroll view, below the pinned
  /// header.
  static Widget sliverBody({required List<Widget> slivers, Key? key}) =>
      Builder(
        builder: (context) => CustomScrollView(
          key: key,
          primary: true,
          slivers: [overlapInjector(context), ...slivers],
        ),
      );

  /// A [body] holding one [child] that fills what the pinned header leaves.
  static Widget boxBody(Widget child, {bool scrolls = false}) => sliverBody(
    slivers: [SliverFillRemaining(hasScrollBody: scrolls, child: child)],
  );

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    final pinned = this.pinned;
    return NestedScrollView(
      key: nestedKey,
      headerSliverBuilder: (context, _) => [
        if (header != null) SliverToBoxAdapter(child: header),
        if (pinned != null)
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: PinnedHeaderSliver(
              // Opaque, so the cards do not show through it.
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: pinned,
              ),
            ),
          ),
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
