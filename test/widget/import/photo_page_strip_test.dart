// BUT-1274: widget gates for PhotoPageStrip (BUT-903 multi-page photo import).
//
// The strip is the only place the user sees and manipulates the ordered set of
// cookbook pages combined into one recipe. These tests pin its user-visible
// contract against a fake ViewModel:
//   - one thumbnail tile per page (index 0 is the cover);
//   - the remove button is wired to removePage(index);
//   - the reorder handles wire onReorder → reorderPage (only with 2+ pages);
//   - the "add page" tile disappears once the maxPages cap is reached;
//   - the whole strip is hidden when there are no pages.
//
// Asserts behaviour (tile count, callback wiring, cap-driven affordance), not
// pixel layout, so it needs no human visual sign-off.

library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/photo_import/photo_page_strip.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// A self-contained ChangeNotifier fake exposing exactly the surface
/// PhotoPageStrip reads, plus recorders for the mutation callbacks. Mocking the
/// real VM (camera/OCR/draft pipeline) would be heavier than the widget under
/// test; the strip only needs the page list + the three actions.
class _FakeStripViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  _FakeStripViewModel({
    required int pageCount,
    this.isProcessing = false,
  }) : _pages = List<Uint8List>.generate(
         pageCount,
         (_) => _onePixelPng,
       );

  final List<Uint8List> _pages;

  @override
  final bool isProcessing;

  int? removedIndex;
  int? reorderOld;
  int? reorderNew;

  @override
  List<Uint8List> get pageImages => List.unmodifiable(_pages);

  @override
  int get pageCount => _pages.length;

  @override
  bool get hasMultiplePages => _pages.length > 1;

  @override
  bool get canAddPage => _pages.length < PhotoImportViewModel.maxPages;

  @override
  Future<void> removePage(int index) async {
    removedIndex = index;
  }

  @override
  Future<void> reorderPage(int oldIndex, int newIndex) async {
    reorderOld = oldIndex;
    reorderNew = newIndex;
  }

  @override
  Future<void> addPageFromCamera() async {}

  @override
  Future<void> addPageFromGallery() async {}

  /// Valid 1x1 transparent PNG so Image.memory can decode each thumbnail.
  static final Uint8List _onePixelPng = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pumpStrip(WidgetTester tester, _FakeStripViewModel vm) async {
    // The strip is a horizontal lazy ReorderableListView, so off-screen tiles
    // aren't built. Widen the viewport so all five capped pages + the add tile
    // are realized and findable by key.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createLocalizedTestApp(child: PhotoPageStrip(viewModel: vm)),
    );
    await tester.pump();
  }

  testWidgets('renders nothing when there are no pages', (tester) async {
    final vm = _FakeStripViewModel(pageCount: 0);
    await pumpStrip(tester, vm);

    // The whole strip collapses to SizedBox.shrink — no thumbnails, no add tile.
    expect(find.byType(Image), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
  });

  testWidgets('renders exactly one thumbnail tile per page', (tester) async {
    final vm = _FakeStripViewModel(pageCount: 3);
    await pumpStrip(tester, vm);

    // Three pages ⇒ three page-keyed thumbnails (the add tile keeps its own
    // distinct key, so it is not counted here).
    expect(find.byKey(const ValueKey('photo-page-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-page-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-page-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-page-3')), findsNothing);
  });

  testWidgets('tapping a page remove button calls removePage with its index', (
    tester,
  ) async {
    final vm = _FakeStripViewModel(pageCount: 2);
    await pumpStrip(tester, vm);

    // Invoke the remove callback on the second page's tile → removePage(1).
    // The horizontal reorderable strip can lay later tiles past the viewport
    // edge, so we fire the wired callback directly rather than hit-testing.
    final removeOnPage1 = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('photo-page-1')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      removeOnPage1.onPressed,
      isNotNull,
      reason: 'an idle page tile must offer an enabled remove button',
    );
    removeOnPage1.onPressed!();
    await tester.pump();

    expect(vm.removedIndex, 1);
  });

  testWidgets('reorder is wired to reorderPage when multiple pages exist', (
    tester,
  ) async {
    final vm = _FakeStripViewModel(pageCount: 3);
    await pumpStrip(tester, vm);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // Drag handles only exist with 2+ pages; the strip drives onReorder
    // straight through to the VM so a drop persists the new page order.
    expect(list.buildDefaultDragHandles, isTrue);
    list.onReorder(2, 0);
    expect(vm.reorderOld, 2);
    expect(vm.reorderNew, 0);
  });

  // The add tile is the list FOOTER. In a horizontal lazy ReorderableListView
  // the footer sits past the last item and isn't built until scrolled into
  // view, so asserting on the rendered key is unreliable. Instead assert the
  // widget config the cap drives: footer present under the cap, null at it
  // (the strip wires `footer: canAddPage ? _AddPageTile(...) : null`).
  ReorderableListView strip(WidgetTester tester) =>
      tester.widget<ReorderableListView>(find.byType(ReorderableListView));

  testWidgets('shows the add-page tile while under the maxPages cap', (
    tester,
  ) async {
    final vm = _FakeStripViewModel(
      pageCount: PhotoImportViewModel.maxPages - 1,
    );
    await pumpStrip(tester, vm);

    expect(
      strip(tester).footer,
      isNotNull,
      reason: 'under the cap the user can still add a page',
    );
  });

  testWidgets('hides the add-page tile once the maxPages cap is reached', (
    tester,
  ) async {
    final vm = _FakeStripViewModel(pageCount: PhotoImportViewModel.maxPages);
    await pumpStrip(tester, vm);

    // At the cap the footer add tile is gone — the only way to add more is to
    // remove a page first.
    expect(
      strip(tester).footer,
      isNull,
      reason: 'at the cap the add affordance must disappear',
    );
    // All five capped pages are present as list items.
    expect(strip(tester).itemCount, PhotoImportViewModel.maxPages);
  });

  testWidgets('disables the remove buttons while OCR is processing', (
    tester,
  ) async {
    final vm = _FakeStripViewModel(pageCount: 2, isProcessing: true);
    await pumpStrip(tester, vm);

    // Mutations are blocked mid-OCR so the page set can't change under the
    // in-flight combine+parse: every remove IconButton is disabled (no callback).
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons, isNotEmpty);
    expect(
      buttons.every((b) => b.onPressed == null),
      isTrue,
      reason: 'remove buttons must be disabled while processing',
    );
  });

  testWidgets('remove buttons are enabled when not processing', (tester) async {
    final vm = _FakeStripViewModel(pageCount: 2);
    await pumpStrip(tester, vm);

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons, isNotEmpty);
    expect(buttons.every((b) => b.onPressed != null), isTrue);
  });

  // Gap (BUT-1274 review): page order is the OCR concatenation order, and the
  // user reads that order off the per-tile "Sida N" labels. The strip numbers
  // pages 1-based (index+1); an off-by-one — or a 0-based slip — would label the
  // cover "Sida 0" and silently misrepresent which photo is page one. The
  // original suite asserted tile COUNT and callback indices but never the
  // rendered numbering the user actually sees, so it would miss that regression.
  testWidgets('labels the pages 1-based in capture order (cover is "Sida 1")', (
    tester,
  ) async {
    final vm = _FakeStripViewModel(pageCount: 3);
    await pumpStrip(tester, vm);

    // Scope each label assertion to its keyed tile so the off-by-one is pinned
    // to the right index (page-0 tile must read "Sida 1", page-1 → "Sida 2").
    // Scoping by key also sidesteps the lazy list not realizing the last tile.
    String labelOf(int index) {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('photo-page-$index')),
          matching: find.textContaining('Sida '),
        ),
      );
      return text.data!;
    }

    // Two on-screen tiles are enough to pin the 1-based mapping (index 0 → page
    // one, index 1 → page two); the lazy horizontal list may not realize the
    // third tile's subtree, so we don't assert on it here.
    expect(
      labelOf(0),
      'Sida 1',
      reason: 'the cover tile is page one, not zero',
    );
    expect(labelOf(1), 'Sida 2');
  });
}
