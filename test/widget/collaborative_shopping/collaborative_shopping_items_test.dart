// test/widget/collaborative_shopping/collaborative_shopping_items_test.dart
//
// BUT-238: widget test for the split-store collaborative shopping view.
// Exercises the ViewModel seam via a thin subclass — we fake the data
// surface directly rather than wire up the full UnifiedShoppingService.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_items.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// Fake VM that shadows the parts of CollaborativeShoppingViewModel the
/// widget reads. Avoids plumbing the full shopping service + DI stack
/// for a widget-level test.
class _FakeCollaborativeShoppingViewModel extends ChangeNotifier
    implements CollaborativeShoppingViewModel {
  _FakeCollaborativeShoppingViewModel({
    required this.items,
    this.viewMode = ShoppingViewMode.all,
    this.onClaim,
  });

  List<UnifiedShoppingItem> items;

  @override
  ShoppingViewMode viewMode;

  @override
  String? get currentUserId => 'me';

  @override
  bool get canEdit => true;

  @override
  bool get canView => true;

  @override
  List<Map<String, dynamic>> get activeShoppers =>
      const <Map<String, dynamic>>[];

  final ClaimResult Function(String itemId)? onClaim;

  @override
  int get totalItems => items.length;

  @override
  List<UnifiedShoppingItem> get activeItems =>
      items.where((i) => !i.bought).toList();

  @override
  List<UnifiedShoppingItem> get completedItemsList =>
      items.where((i) => i.bought).toList();

  @override
  int get completedItemsCount => completedItemsList.length;

  @override
  List<UnifiedShoppingItem> get myItems =>
      activeItems.where((i) => i.assignedToUserId == currentUserId).toList();

  @override
  List<UnifiedShoppingItem> get othersItems => activeItems
      .where(
        (i) =>
            i.assignedToUserId != null && i.assignedToUserId != currentUserId,
      )
      .toList();

  @override
  List<UnifiedShoppingItem> get unassignedItems =>
      activeItems.where((i) => i.assignedToUserId == null).toList();

  @override
  bool get hasActiveShoppers => activeShoppers.isNotEmpty;

  @override
  void setViewMode(ShoppingViewMode mode) {
    viewMode = mode;
    notifyListeners();
  }

  @override
  Future<ClaimResult> claimItem(String itemId) async {
    return onClaim?.call(itemId) ?? const ClaimResult(ClaimOutcome.claimed);
  }

  @override
  Future<ClaimResult> unclaimItem(String itemId) async {
    return const ClaimResult(ClaimOutcome.unclaimed);
  }

  @override
  String? getItemSubtitle(UnifiedShoppingItem item) => null;

  @override
  List<Widget> getItemTrailingWidgets(UnifiedShoppingItem item) =>
      const <Widget>[];

  // --- Everything else throws — surfaces accidental usage in tests ---

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _themedApp(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

UnifiedShoppingItem _item({
  required String id,
  required String name,
  String? assignedTo,
  String? assignedDisplayName,
  bool bought = false,
}) => UnifiedShoppingItem(
  id: id,
  name: name,
  amount: 1,
  unit: '',
  category: ShoppingCategory.other,
  bought: bought,
  assignedToUserId: assignedTo,
  assignedToDisplayName: assignedDisplayName,
);

void main() {
  group('CollaborativeShoppingItems (BUT-238)', () {
    UnifiedShoppingItem item({
      required String id,
      required String name,
      String? assignedTo,
      String? assignedDisplayName,
      bool bought = false,
      String category = ShoppingCategory.other,
    }) {
      return UnifiedShoppingItem(
        id: id,
        name: name,
        amount: 1,
        unit: '',
        category: category,
        bought: bought,
        assignedToUserId: assignedTo,
        assignedToDisplayName: assignedDisplayName,
        assignedAt: assignedTo != null ? DateTime.now() : null,
      );
    }

    testWidgets('Alla mode: renders flat list of all items', (tester) async {
      final vm = _FakeCollaborativeShoppingViewModel(
        items: [
          item(id: '1', name: 'Mjölk'),
          item(id: '2', name: 'Ägg'),
        ],
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: CollaborativeShoppingItems(
            viewModel: vm,
            onToggleItem: (_) {},
          ),
        ),
      );

      expect(find.text('Mjölk'), findsOneWidget);
      expect(find.text('Ägg'), findsOneWidget);
    });

    testWidgets(
      'Min del mode: splits items into Min del / Annas del / Otilldelat',
      (tester) async {
        final vm = _FakeCollaborativeShoppingViewModel(
          viewMode: ShoppingViewMode.myPart,
          items: [
            item(
              id: '1',
              name: 'Mjölk',
              assignedTo: 'me',
              assignedDisplayName: 'Me',
            ),
            item(
              id: '2',
              name: 'Bröd',
              assignedTo: 'anna',
              assignedDisplayName: 'Anna',
            ),
            item(id: '3', name: 'Pasta'), // unassigned
          ],
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: CollaborativeShoppingItems(
              viewModel: vm,
              onToggleItem: (_) {},
            ),
          ),
        );

        // All three section headers should render.
        // Swedish strings from the ARB: "Min del", "Annas del", "Otilldelat".
        expect(
          find.textContaining('MIN DEL', findRichText: false),
          findsOneWidget,
        );
        expect(
          find.textContaining('OTILLDELAT', findRichText: false),
          findsOneWidget,
        );
        // "Annas del" — uppercased header reads "ANNAS DEL".
        expect(find.textContaining('ANNAS DEL'), findsOneWidget);

        expect(find.text('Mjölk'), findsOneWidget);
        expect(find.text('Bröd'), findsOneWidget);
        expect(find.text('Pasta'), findsOneWidget);
      },
    );

    testWidgets('Efter zon mode: groups items by ShoppingCategory', (
      tester,
    ) async {
      final vm = _FakeCollaborativeShoppingViewModel(
        viewMode: ShoppingViewMode.byZone,
        items: [
          item(id: '1', name: 'Mjölk', category: ShoppingCategory.dairy),
          item(id: '2', name: 'Äpple', category: ShoppingCategory.fruitVeg),
        ],
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: CollaborativeShoppingItems(
            viewModel: vm,
            onToggleItem: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mjölk'), findsOneWidget);
      expect(find.text('Äpple'), findsOneWidget);
    });

    testWidgets('claim flow: tap Tar jag triggers claim', (tester) async {
      final claimed = <String>[];
      final vm = _FakeCollaborativeShoppingViewModel(
        items: [item(id: '1', name: 'Mjölk')],
        onClaim: (id) {
          claimed.add(id);
          return const ClaimResult(ClaimOutcome.claimed);
        },
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: CollaborativeShoppingItems(
            viewModel: vm,
            onToggleItem: (_) {},
          ),
        ),
      );

      // "Tar jag" button appears on unassigned items for editors.
      final claimButton = find.text('Tar jag');
      expect(claimButton, findsOneWidget);
      await tester.tap(claimButton);
      await tester.pump();

      expect(claimed, equals(['1']));
    });

    testWidgets('claim conflict: snackbar surfaces "nn tog den"', (
      tester,
    ) async {
      final vm = _FakeCollaborativeShoppingViewModel(
        items: [item(id: '1', name: 'Mjölk')],
        onClaim: (_) => const ClaimResult(
          ClaimOutcome.conflict,
          conflictingDisplayName: 'Anna',
        ),
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: CollaborativeShoppingItems(
            viewModel: vm,
            onToggleItem: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Tar jag'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Expect the snackbar with the conflicting user's name — Swedish copy.
      expect(find.textContaining('Anna'), findsWidgets);
    });

    testWidgets('view mode toggle switches between modes', (tester) async {
      final vm = _FakeCollaborativeShoppingViewModel(
        items: [
          item(id: '1', name: 'Mjölk'),
        ],
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: CollaborativeShoppingItems(
            viewModel: vm,
            onToggleItem: (_) {},
          ),
        ),
      );

      // Tapping "Min del" should call setViewMode — via the segmented button.
      await tester.tap(find.text('Min del'));
      await tester.pump();

      expect(vm.viewMode, equals(ShoppingViewMode.myPart));
    });
  });

  // BUT-2183: the old half-opacity steps are gone. Rows that are someone
  // else's or done stand on surface.base instead of a faded raised fill, and
  // the other-people header is text.secondary, not a faded copy of it.
  group('CollaborativeShoppingItems on the B83 tokens (BUT-2183)', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('$name: other people\'s and done rows stand on surface.base, '
          'their header is text.secondary', (tester) async {
        final cs = theme.colorScheme;
        final vm = _FakeCollaborativeShoppingViewModel(
          viewMode: ShoppingViewMode.myPart,
          items: [
            _item(
              id: '1',
              name: 'Mjölk',
              assignedTo: 'me',
              assignedDisplayName: 'Me',
            ),
            _item(
              id: '2',
              name: 'Bröd',
              assignedTo: 'anna',
              assignedDisplayName: 'Anna',
            ),
            _item(id: '3', name: 'Pasta', bought: true),
          ],
        );

        await tester.pumpWidget(
          _themedApp(
            theme,
            CollaborativeShoppingItems(viewModel: vm, onToggleItem: (_) {}),
          ),
        );

        Card cardOf(String text) => tester.widget<Card>(
          find.ancestor(of: find.text(text), matching: find.byType(Card)).first,
        );
        expect(cardOf('Bröd').color, cs.surface);
        expect(cardOf('Pasta').color, cs.surface);
        expect(
          cardOf('Mjölk').color,
          isNull,
          reason: 'my own open row keeps the card theme (surface.raised)',
        );

        Color? headerColor(String text) =>
            tester.widget<Text>(find.textContaining(text)).style?.color;
        expect(headerColor('ANNAS DEL'), cs.onSurfaceVariant);
        expect(headerColor('MIN DEL'), cs.onSurface);
      });
    }
  });
}
