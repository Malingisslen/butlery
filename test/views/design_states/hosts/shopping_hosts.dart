/// P8-U01 hosts: the shopping list (five rows), the pantry (four) and the
/// shared list offline (vänner-grupp OFFLINE).
///
/// The shopping tab is UnifiedShoppingView with the real
/// UnifiedShoppingViewModel over a mocked service. The pantry is the same
/// view's Skafferi tab (lib/views/unified_shopping_view.dart:238-243), whose
/// PantryView reads a mocked PantryViewModel. The add sheet opens over the
/// pantry as the pantry's own "Lägg till" opens it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/social/collaborative_shopping_view.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart';
import 'package:butlery/views/unified_shopping_view.dart';

import '../../../helpers/user_profile_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_harness.dart';
import '../state_host.dart';
import 'host_helpers.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

/// The user's category order, read from a repository with nothing stored.
ShoppingCategoryPreferencesModule _categoryPreferences() {
  final repository = _MockCategoryPreferences();
  when(repository.getPreferences).thenAnswer((_) async => null);
  return ShoppingCategoryPreferencesModule(repository: repository);
}

const _me = 'test-user-123';
final _addedAt = DateTime(2026, 9, 21, 9);

UnifiedShoppingItem _item(
  String id,
  String name,
  String category, {
  double amount = 1,
  String unit = 'st',
  bool bought = false,
}) => ShoppingListFactory.buildItem(
  id: id,
  name: name,
  amount: amount,
  unit: unit,
  category: category,
  bought: bought,
  addedAt: _addedAt,
);

List<UnifiedShoppingItem> _weekItems() => [
  _item('i1', 'Röda linser', 'Torrvaror', amount: 3, unit: 'dl'),
  _item('i2', 'Kokosmjölk', 'Konserver', amount: 1, unit: 'burk'),
  _item('i3', 'Gul lök', 'Frukt & grönt', amount: 2),
  _item('i4', 'Koriander', 'Frukt & grönt', bought: true),
  _item('i5', 'Havremjölk', 'Mejeri', amount: 1, unit: 'l'),
];

UnifiedShoppingList _list(
  List<UnifiedShoppingItem> items, {
  String id = 'list-vecka',
  ListType type = ListType.personal,
  Map<String, SharedListPermission>? members,
}) => ShoppingListFactory.build(
  id: id,
  name: 'Veckans inköp',
  ownerId: _me,
  ownerDisplayName: 'Malin',
  items: items,
  type: type,
  memberPermissions: members,
  createdAt: _addedAt,
  updatedAt: _addedAt,
);

/// The shopping tab over a service holding [list], or no list at all.
Widget _shopping(UnifiedShoppingList? list) {
  final service = MockUnifiedShoppingService()
    ..setShoppingState(lists: [?list], activeListId: list?.id);
  when(service.loadLists).thenAnswer((_) async {});
  when(service.initialize).thenAnswer((_) async {});
  // Built before the stub: mocktail refuses a when() inside a when().
  final preferences = _categoryPreferences();
  when(() => service.categoryPreferences).thenReturn(preferences);
  TestServiceLocator.registerMock<UnifiedShoppingService>(service);
  TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
    UnifiedShoppingViewModel(),
  );
  return const UnifiedShoppingView();
}

/// The pantry's view model in one of its states.
_MockPantryViewModel _pantry({
  bool loading = false,
  List<PantryItem> items = const [],
}) {
  final vm = _MockPantryViewModel();
  when(() => vm.isLoading).thenReturn(loading);
  when(() => vm.error).thenReturn(null);
  when(() => vm.hasError).thenReturn(false);
  when(() => vm.items).thenReturn(items);
  when(() => vm.expiringItems).thenReturn(items);
  when(() => vm.itemsByLocation(any())).thenReturn(const []);
  when(() => vm.searchResults).thenReturn(const []);
  when(vm.loadPantry).thenAnswer((_) async {});
  return vm;
}

List<PantryItem> _pantryItems() => [
  PantryItem(
    id: 'p1',
    ingredientName: 'Havremjölk',
    quantity: 1,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: _addedAt,
    expiryDate: DateTime(2026, 9, 30),
  ),
  PantryItem(
    id: 'p2',
    ingredientName: 'Röda linser',
    quantity: 500,
    unit: 'g',
    location: PantryLocation.pantry,
    addedAt: _addedAt,
    expiryDate: DateTime(2026, 9, 29),
  ),
];

/// The pantry tab of the shopping view. The shopping service holds no list.
Widget _pantryTab(_MockPantryViewModel vm) {
  TestServiceLocator.registerFactory<PantryViewModel>(() => vm);
  return _shopping(null);
}

Future<void> _openPantryTab(WidgetTester tester, HostContext ctx) async {
  await tester.tap(find.text(sv.shoppingTabPantry));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The service each pumped shared list reads, so a member's change can
/// arrive while the list is open.
final _collaborative = Expando<MockUnifiedShoppingService>();

UnifiedShoppingList _shared(List<UnifiedShoppingItem> items) => _list(
  items,
  id: 'list-delad',
  type: ListType.collaborative,
  members: const {
    _me: SharedListPermission.admin,
    'u-per': SharedListPermission.edit,
  },
);

Widget _collaborativeView(HostContext ctx) {
  final service = MockUnifiedShoppingService()
    ..setShoppingState(
      lists: [_shared(_weekItems().take(3).toList())],
      collaborativeLists: [_shared(_weekItems().take(3).toList())],
      activeListId: 'list-delad',
    );
  when(service.loadLists).thenAnswer((_) async {});
  TestServiceLocator.registerMock<UnifiedShoppingService>(service);
  _collaborative[ctx] = service;
  return const CollaborativeShoppingView(listId: 'list-delad');
}

/// The invitation layer the member dialog invites through; its call never
/// answers, so the dialog stays busy.
class _PendingInvitations extends Fake implements ListInvitationOperations {
  @override
  String? get currentUserId => null;

  @override
  Stream<List<SocialRequest>> pendingSentForList(String listId) =>
      const Stream.empty();

  @override
  Future<ListInviteSummary> invite({
    required String listId,
    required List<String> userIds,
    String permission = 'edit',
  }) => Completer<ListInviteSummary>().future;
}

final shoppingHosts = <String, StateHost>{
  'inköpslista::DEFAULT': StateHost(
    build: (ctx) async => _shopping(_list(_weekItems())),
  ),
  'inköpslista::EMPTY': StateHost(
    build: (ctx) async => _shopping(_list(const [])),
  ),
  'inköpslista::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _shopping(_list(_weekItems())),
  ),
  // BEVIS is the member dialog: inviting a friend to the shared list is the
  // list's loading state that has a drawing-free busy form.
  'inköpslista::LOADING': StateHost(
    build: (ctx) async {
      final UserProfile friend = testUserProfile(
        uid: 'u-cecilia',
        displayName: 'Cecilia',
      );
      return OpensOnMount(
        page: const Scaffold(body: SizedBox.expand()),
        open: (context) => unawaited(
          showDialog<bool>(
            context: context,
            builder: (_) => ShoppingMemberManagementDialog(
              list: _shared(const []),
              userDisplayNames: const {
                _me: 'Malin',
                'u-per': 'Per',
                'u-cecilia': 'Cecilia',
              },
              availableFriends: [friend],
              invitations: _PendingInvitations(),
            ),
          ),
        ),
      );
    },
    reach: (tester, ctx) async {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cecilia').last);
      await tester.pump();
      final add = find.text(sv.listInviteButtonCount(1));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
    },
  ),
  // union of operations, and a banner saying what
  // the other member did. Per adds a row while Malin has the list open.
  'inköpslista::CONFLICT': StateHost(
    conflictItems: (local: 'Röda linser', remote: 'Vetemjöl'),
    build: (ctx) async => _collaborativeView(ctx),
    reach: (tester, ctx) async {
      await tester.pump(const Duration(milliseconds: 50));
      final merged =
          _shared([
            ..._weekItems().take(3),
            _item('i9', 'Vetemjöl', 'Torrvaror', amount: 2, unit: 'kg'),
          ]).copyWith(
            lastActivityAt: _addedAt.add(const Duration(minutes: 5)),
            lastActivityByUserId: 'u-per',
            lastActivityByDisplayName: 'Per',
          );
      _collaborative[ctx]!.emitState(
        ShoppingStateData(lists: [merged], activeListId: merged.id),
      );
      await tester.pump();
      await tester.pump();
    },
  ),
  'vänner-grupp::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _collaborativeView(ctx),
    reach: (tester, ctx) => tester.pump(const Duration(milliseconds: 50)),
  ),
  // The add sheet over the pantry, opened as the pantry's "Lägg till"
  // opens it (a scroll-controlled bottom sheet).
  'skafferi::DEFAULT': StateHost(
    build: (ctx) async {
      final vm = _pantry(items: _pantryItems());
      return ChangeNotifierProvider<PantryViewModel>.value(
        value: vm,
        child: OpensOnMount(
          page: const Scaffold(body: SizedBox.expand()),
          open: (context) => unawaited(
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ChangeNotifierProvider<PantryViewModel>.value(
                value: vm,
                child: const AddPantryItemSheet(),
              ),
            ),
          ),
        ),
      );
    },
  ),
  'skafferi::EMPTY': StateHost(
    build: (ctx) async => _pantryTab(_pantry()),
    reach: _openPantryTab,
  ),
  'skafferi::LOADING': StateHost(
    build: (ctx) async => _pantryTab(_pantry(loading: true)),
    reach: _openPantryTab,
  ),
  'skafferi::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _pantryTab(_pantry(items: _pantryItems())),
    reach: _openPantryTab,
  ),
};

/// The pantry with two items, online: the Skafferi key screen of the Linux
/// goldens (test/views/golden_linux), which is not one of the 53 rows.
final StateHost pantryWithItemsHost = StateHost(
  build: (ctx) async => _pantryTab(_pantry(items: _pantryItems())),
  reach: _openPantryTab,
);

/// The pantry as the sketch draws it (06): two items about to expire, then
/// the fridge, freezer and pantry with one item each.
final StateHost pantrySketchHost = StateHost(
  build: (ctx) async {
    PantryItem item(
      String id,
      String name,
      double quantity,
      String unit,
      PantryLocation location, {
      DateTime? expiry,
    }) => PantryItem(
      id: id,
      ingredientName: name,
      quantity: quantity,
      unit: unit,
      location: location,
      addedAt: _addedAt,
      expiryDate: expiry,
    );
    final expiring = [
      item(
        'p1',
        'Grädde',
        2,
        'dl',
        PantryLocation.fridge,
        expiry: DateTime(2026, 9, 29),
      ),
      item(
        'p2',
        'Babyspenat',
        1,
        'påse',
        PantryLocation.fridge,
        expiry: DateTime(2026, 9, 30),
      ),
    ];
    final rest = [
      item('p3', 'Smör', 1, 'paket', PantryLocation.fridge),
      item('p4', 'Parmesan', 1, 'bit', PantryLocation.fridge),
      item('p5', 'Ärtor', 1, 'påse', PantryLocation.freezer),
      item('p6', 'Pasta', 1, 'paket', PantryLocation.pantry),
      item('p7', 'Spiskummin', 1, 'burk', PantryLocation.spiceRack),
    ];
    final vm = _pantry(items: [...expiring, ...rest]);
    when(() => vm.expiringItems).thenReturn(expiring);
    when(() => vm.itemsByLocation(any())).thenAnswer(
      (call) => [
        for (final p in rest)
          if (p.location == call.positionalArguments.first) p,
      ],
    );
    return _pantryTab(vm);
  },
  reach: _openPantryTab,
);

/// A shared list with a claimed item, a free one and two bought: the shared
/// list of sketch frame 10.
final StateHost sharedListSketchHost = StateHost(
  build: (ctx) async {
    final items = [
      _item('s1', 'Jordgubbar', 'Frukt & grönt', amount: 3, unit: 'l'),
      _item('s2', 'Färskpotatis', 'Frukt & grönt', amount: 2, unit: 'kg'),
      _item('s3', 'Gräddfil', 'Mejeri', amount: 2),
      _item('s4', 'Sill', 'Torrvaror', amount: 2, unit: 'burkar', bought: true),
      _item('s5', 'Snaps', 'Drycker', bought: true),
    ];
    final list = _shared(items);
    final service = MockUnifiedShoppingService()
      ..setShoppingState(
        lists: [list],
        collaborativeLists: [list],
        activeListId: list.id,
      );
    when(service.loadLists).thenAnswer((_) async {});
    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    return CollaborativeShoppingView(listId: list.id);
  },
);
