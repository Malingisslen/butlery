import 'package:flutter/foundation.dart';

import 'package:butlery/core/di/household_links_from_locator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/shopping/dismissed_dietary_hints_store.dart';
import 'package:butlery/services/shopping/shopping_dietary_hints.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/shopping/household_shopping_choices.dart';

/// One shopping row as the reminder sees it: an id to key dismissals on and
/// the name the shopper typed.
typedef HintRow = ({String id, String name});

/// Works out the allergy reminders for the rows of the list on screen
/// (BUT-2494). Everything happens on this device: nothing is written to the
/// rows or the list, so other members never see what this one is reminded of.
///
/// Cost: the household choices come from [HouseholdShoppingChoices], and
/// each distinct item name is looked up once per controller against the
/// global ingredient data, without a user id. With no choices nothing is
/// looked up at all.
class ShoppingDietaryHintsController extends ChangeNotifier {
  ShoppingDietaryHintsController({
    required Future<Set<String>> Function() loadChoices,
    required Future<List<Set<String>?>> Function(List<String> names) lookup,
    required String? Function() currentUserId,
    DismissedDietaryHintsStore store = const DismissedDietaryHintsStore(),
  }) : _loadChoices = loadChoices,
       _lookup = lookup,
       _currentUserId = currentUserId,
       _store = store;

  factory ShoppingDietaryHintsController.fromLocator() {
    final users = ServiceLocator.tryGet<OwnProfileReader>();
    final permissions = ServiceLocator.tryGet<PermissionService>();
    final ingredients = ServiceLocator.tryGet<IngredientLookupService>();
    final choices = HouseholdShoppingChoices(
      links: householdLinksFromLocator(),
      ownProfile: () => users?.currentUserProfile,
    );
    return ShoppingDietaryHintsController(
      loadChoices: choices.load,
      lookup: (names) => lookupProperties(ingredients, names),
      currentUserId: () => permissions?.currentUserId,
    );
  }

  /// The ingredient properties for each of [names], in order; null where the
  /// data does not know the name. Only whole matches count: the lookup's
  /// dish fallback ("räksallad" → räkor) is a guess about one ingredient of
  /// many, too loose for a reminder.
  @visibleForTesting
  static Future<List<Set<String>?>> lookupProperties(
    IngredientLookupService? service,
    List<String> names,
  ) async {
    if (service == null) return [for (final _ in names) null];
    final result = await service.lookupFromRaw(names);
    final lines = result.lines;
    return [
      for (var i = 0; i < names.length; i++)
        i < lines.length && lines[i].known
            ? {for (final data in lines[i].ingredients) ...data.properties}
            : null,
    ];
  }

  final Future<Set<String>> Function() _loadChoices;
  final Future<List<Set<String>?>> Function(List<String> names) _lookup;
  final String? Function() _currentUserId;
  final DismissedDietaryHintsStore _store;

  String? _uid;
  Set<String> _dismissed = {};
  final Map<String, Set<String>?> _propertiesByName = {};
  Map<String, List<ShoppingDietaryHint>> _hintsByItem = const {};
  List<HintRow> _rows = const [];
  String? _lastSignature;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// The reminders still showing for [itemId].
  List<ShoppingDietaryHint> hintsFor(String itemId) => [
    for (final hint in _hintsByItem[itemId] ?? const <ShoppingDietaryHint>[])
      if (!_dismissed.contains(
        DismissedDietaryHintsStore.entry(itemId, hint.choiceKey),
      ))
        hint,
  ];

  /// Whether any row on screen still shows a reminder, which is when the list
  /// carries its "Läs alltid innehållet" line (ADR-0044).
  bool get hasVisibleHints =>
      _hintsByItem.keys.any((itemId) => hintsFor(itemId).isNotEmpty);

  /// Recomputes for [rows] when they or the signed-in account changed.
  Future<void> update(List<HintRow> rows) async {
    final uid = _currentUserId();
    final signature =
        '$uid\u0000${[for (final r in rows) '${r.id}=${r.name}'].join('\u0000')}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    _rows = rows;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _compute();
      } while (_again && !_disposed);
    } finally {
      _running = false;
    }
  }

  Future<void> _compute() async {
    final uid = _currentUserId();
    if (uid != _uid) {
      _uid = uid;
      _dismissed = {};
      _propertiesByName.clear();
      _hintsByItem = const {};
      if (uid != null) _dismissed = await _store.read(uid);
    }
    if (uid == null) return _publish(const {});

    // Asked again on every recompute: the household part is cached for ten
    // minutes, and the viewer's own settings may have merged since.
    final choices = await _loadChoices();
    if (_stale(uid)) return;
    if (choices.isEmpty) return _publish(const {});

    final rows = _rows;
    final unknown = {
      for (final row in rows)
        if (!_propertiesByName.containsKey(row.name)) row.name,
    }.toList();
    if (unknown.isNotEmpty) {
      // Marked as tried before the await: one attempt per name, so an
      // offline cold start does not reload the ingredient data per rebuild.
      for (final name in unknown) {
        _propertiesByName[name] = null;
      }
      try {
        final found = await _lookup(unknown);
        if (_stale(uid)) return;
        for (var i = 0; i < unknown.length && i < found.length; i++) {
          _propertiesByName[unknown[i]] = found[i];
        }
      } catch (e) {
        AppLogger.warning('Shopping reminder lookup failed: $e');
      }
    }

    _publish({
      for (final row in rows)
        row.id: ShoppingDietaryHints.forItem(
          itemName: row.name,
          properties: _propertiesByName[row.name],
          householdChoices: choices,
        ),
    });
  }

  bool _stale(String uid) => _disposed || _currentUserId() != uid;

  void _publish(Map<String, List<ShoppingDietaryHint>> hints) {
    if (_disposed) return;
    _hintsByItem = hints;
    notifyListeners();
  }

  Future<void> dismiss(String itemId, String choiceKey) =>
      _setDismissed(itemId, choiceKey, dismissed: true);

  Future<void> undoDismiss(String itemId, String choiceKey) =>
      _setDismissed(itemId, choiceKey, dismissed: false);

  Future<void> _setDismissed(
    String itemId,
    String choiceKey, {
    required bool dismissed,
  }) async {
    final uid = _uid;
    if (uid == null || _disposed) return;
    final entry = DismissedDietaryHintsStore.entry(itemId, choiceKey);
    _dismissed = {..._dismissed}..remove(entry);
    if (dismissed) _dismissed.add(entry);
    notifyListeners();
    // Not after a sign-out: the store was just cleared for that account.
    if (_currentUserId() != uid) return;
    await _store.write(uid, _dismissed);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
