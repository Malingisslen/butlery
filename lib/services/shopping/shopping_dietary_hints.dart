import 'package:butlery/services/tagging/config/allergen_config.dart';

/// What the reminder under a shopping row asks of the shopper.
enum ShoppingDietaryHintKind {
  /// A free variant exists on the shelf ("Laktos i hushållet, välj laktosfri").
  chooseFreeVariant,

  /// No free variant to point at, so the shopper reads the pack
  /// ("Innehåller ofta nötter, kolla innehållet").
  checkContents,
}

/// One reminder for one household choice on one shopping row.
class ShoppingDietaryHint {
  const ShoppingDietaryHint({required this.choiceKey, required this.kind});

  /// The allergen key as stored in `trackedAllergens` (`laktos`, `nötter`).
  final String choiceKey;
  final ShoppingDietaryHintKind kind;

  @override
  bool operator ==(Object other) =>
      other is ShoppingDietaryHint &&
      other.choiceKey == choiceKey &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(choiceKey, kind);

  @override
  String toString() => 'ShoppingDietaryHint($choiceKey, ${kind.name})';
}

/// The reminders a shopping row gets, decided from the item's name and the
/// ingredient-data properties it resolved to. Deterministic: no AI, no reads.
///
/// A reminder is never a promise about the rows WITHOUT one, which is why an
/// item the ingredient data does not know gets nothing rather than a guess.
abstract final class ShoppingDietaryHints {
  /// Choices whose free variant is an ordinary product to pick instead
  /// (Malin 2026-11-23). Milk protein is not among them: lactose-free milk
  /// still contains it.
  static const freeVariantKeys = {'laktos', 'gluten'};

  /// Choices the household buys on purpose, so a reminder on the steak would
  /// be noise (plan BUT-2494).
  static const ignoredKeys = {'kött', 'fläsk', 'nötkött', 'alkohol'};

  /// [properties] is null when the ingredient data has no match for the item.
  static List<ShoppingDietaryHint> forItem({
    required String itemName,
    required Set<String>? properties,
    required Set<String> householdChoices,
  }) {
    if (properties == null || householdChoices.isEmpty) return const [];
    final name = itemName.toLowerCase();

    final hits = <AllergenEntry>[
      for (final entry in AllergenConfig.all)
        if (householdChoices.contains(entry.key) &&
            !ignoredKeys.contains(entry.key) &&
            !_nameSaysFree(name, entry) &&
            entry.triggerProperties.any(properties.contains))
          entry,
    ];
    final hitKeys = {for (final e in hits) e.key};

    return [
      for (final entry in hits)
        if (!_coveredByNarrowerHit(entry, hits) &&
            // Milk allergy outranks lactose: "välj laktosfri" would point a
            // milk-allergic member at a product that still contains milk.
            !(entry.key == 'laktos' && hitKeys.contains('mjölk')))
          ShoppingDietaryHint(
            choiceKey: entry.key,
            kind: freeVariantKeys.contains(entry.key)
                ? ShoppingDietaryHintKind.chooseFreeVariant
                : ShoppingDietaryHintKind.checkContents,
          ),
    ];
  }

  /// Per choice: "glutenfri" in the name says nothing about lactose.
  static bool _nameSaysFree(String lowerName, AllergenEntry entry) {
    final free = entry.freeTag;
    return free != null && lowerName.contains(free);
  }

  /// `nötter` (tree nut OR peanut) next to a `jordnötter` hit would put two
  /// boxes on the same jar; the narrower one says more.
  static bool _coveredByNarrowerHit(
    AllergenEntry entry,
    List<AllergenEntry> hits,
  ) {
    if (!entry.isCombined) return false;
    final parts = entry.triggerProperties.toSet();
    return hits.any(
      (other) =>
          !other.isCombined && other.triggerProperties.every(parts.contains),
    );
  }
}
