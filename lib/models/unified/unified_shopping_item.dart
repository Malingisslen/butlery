/// Comprehensive unified shopping item model providing advanced shopping list functionality with collaborative features.
/// This model implements sophisticated shopping item management following Single Responsibility Principle,
/// handling all aspects of shopping list items including basic functionality, collaborative metadata,
/// smart formatting, and comprehensive user interaction tracking. It provides complete unified shopping
/// capabilities while maintaining clean separation from shopping list management and UI concerns.
/// **Single Responsibility Focus:**
/// This model exclusively handles shopping item management and tracking:
/// - **Basic Shopping Functionality**: Core item data with name, amount, unit, category, and purchase status
/// - **Collaborative Metadata**: Complete user tracking for additions, modifications, and purchases with timestamps
/// - **Smart Formatting**: Intelligent display formatting with Swedish unit mappings and amount optimization
/// - **Priority Management**: Priority system with visual indicators and organizational capabilities
/// **What This Model Does NOT Handle:**
/// - Shopping list composition and management (handled by UnifiedShoppingList and services)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Shopping list persistence and storage operations (handled by repositories and services)
/// - User management and authentication (handled by user services and authentication systems)
/// **Unified Shopping Item Features:**
/// - **Dual Mode Support**: Seamlessly handles both basic personal shopping and collaborative shared shopping
/// - **Smart Formatting**: Intelligent display text generation with Swedish unit abbreviations and amount optimization
/// - **Collaborative Tracking**: Complete user attribution for all item lifecycle events with timestamp precision
/// - **Priority System**: Visual priority management with emoji indicators and organizational sorting support
/// - **Migration Support**: Backward compatibility with legacy shopping item models for seamless upgrades
/// **Usage Examples:**
/// ```dart
/// // Create basic shopping item for personal lists
/// final basicItem = UnifiedShoppingItem.basic(
///   name: 'Mjölk',
///   amount: 1.5,
///   unit: 'liter',
///   category: ShoppingCategory.dairy,
/// );
/// // Create collaborative item for shared lists
/// final collabItem = UnifiedShoppingItem.collaborative(
///   name: 'Ägg',
///   amount: 12,
///   unit: 'styck',
///   category: ShoppingCategory.dairy,
///   addedByUserId: currentUserId,
///   addedByDisplayName: 'Anna Andersson',
///   note: 'Ekologiska om möjligt',
///   estimatedPrice: 45.0,
///   priority: 4,
/// );
/// // Smart formatting examples
/// print(basicItem.displayText); // "1,5 l Mjölk"
/// print(collabItem.displayText); // "12 st Ägg"
/// print(collabItem.priorityEmoji); // "🟠" (high priority)
/// // Toggle purchase status with user tracking
/// final purchasedItem = collabItem.togglePurchased(
///   userId: currentUserId,
///   userDisplayName: 'Erik Svensson',
/// );
/// // Check collaborative features
/// final isCollab = collabItem.isCollaborative; // true
/// final isPurchased = purchasedItem.isPurchased; // true
/// ```

// lib/models/unified/unified_shopping_item.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Language-neutral shopping category constants for Firestore storage.
/// Display labels should use l10n: AppLocale.current.shoppingCat* or context.l10n.shoppingCat*
class ShoppingCategory {
  ShoppingCategory._();
  static const String other = 'other';
  static const String dairy = 'dairy';
  static const String meatFish = 'meat_fish';
  static const String fruitVeg = 'fruit_veg';
  static const String breadGrain = 'bread_grain';
  static const String pantry = 'pantry';
  static const String frozen = 'frozen';
  static const String drinks = 'drinks';
  static const String snacks = 'snacks';
  static const String cleaning = 'cleaning';
  static const String spices = 'spices';
  static const String canned = 'canned';
  static const String dryGoods = 'dry_goods';

  /// BUT-1004: fine-grained splits introduced alongside the legacy aliases.
  /// New categorizer output routes to these; legacy `meatFish`/`fruitVeg`
  /// constants stay valid so old Firestore docs still render through the
  /// switches in [displayName] and the shopping UI.
  static const String meat = 'meat';
  static const String fish = 'fish';
  static const String fruit = 'fruit';
  static const String veg = 'veg';

  /// All valid category constants for iteration. New fine-grained buckets
  /// come first in the section they live in (Swedish store walk) so dropdowns
  /// prefer the modern split. Legacy aggregate keys remain for back-compat.
  static const List<String> all = [
    fruit,
    veg,
    fruitVeg,
    dairy,
    meat,
    fish,
    meatFish,
    breadGrain,
    dryGoods,
    canned,
    pantry,
    spices,
    frozen,
    drinks,
    snacks,
    cleaning,
    other,
  ];

  /// Default category order based on typical Swedish grocery store layout.
  /// Currently matches [all] — separate constant so store-specific layouts
  /// can diverge without affecting iteration logic.
  static const List<String> defaultStoreOrder = all;

  /// Localized display name for a category constant.
  /// Uses AppLocale.current so it works both with and without BuildContext.
  static String displayName(String category) {
    final l = AppLocale.current;
    switch (category) {
      case fruit:
        return l.categoryFruit;
      case veg:
        return l.categoryVeg;
      case fruitVeg:
        return l.categoryFruitVeg;
      case dairy:
        return l.categoryDairy;
      case meat:
        return l.categoryMeat;
      case fish:
        return l.categoryFish;
      case meatFish:
        return l.categoryMeatFish;
      case breadGrain:
        return l.categoryBread;
      case pantry:
        return l.categoryPantry;
      case frozen:
        return l.categoryFrozen;
      case drinks:
        return l.categoryBeverage;
      case snacks:
        return l.categorySnacks;
      case cleaning:
        return l.categoryHygiene;
      case spices:
        return l.categorySpices;
      case canned:
        return l.categoryCanned;
      case dryGoods:
        return l.categoryDryGoods;
      case other:
        return l.categoryOther;
      default:
        return category;
    }
  }

  /// Sort comparator that orders categories by a given order list.
  /// Unknown categories sort to the end.
  static int Function(String, String) orderComparator(List<String> order) {
    return (a, b) {
      final ai = order.indexOf(a);
      final bi = order.indexOf(b);
      return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
    };
  }
}

/// Comprehensive unified shopping item with dual-mode support and collaborative features.
/// Represents a complete shopping item with all associated metadata including basic shopping data,
/// collaborative tracking information, smart formatting capabilities, and priority management.
/// Supports both personal shopping lists and collaborative shared shopping experiences.
class UnifiedShoppingItem {
  /// Unique identifier for this shopping item instance.
  final String id;

  /// Name of the shopping item for identification and display.
  /// The primary identifier for the item that users see and interact with.
  final String name;

  /// Quantity amount for the shopping item with decimal precision support.
  /// Supports both whole numbers and decimal quantities for precise shopping measurements.
  final double amount;

  /// Unit of measurement for the shopping item quantity.
  /// Supports Swedish units with smart formatting and abbreviation mapping for optimal display.
  final String unit;

  /// Category classification for shopping item organization.
  /// Used for grouping and organizing items within shopping lists with Swedish category names.
  final String category;

  /// Purchase status indicating whether the item has been bought.
  /// Core shopping functionality for tracking completed purchases and list progress.
  final bool bought;

  /// Collaborative metadata for enhanced social shopping features (optional - null for basic lists).

  /// User identifier of the person who added this item to the shopping list.
  /// Enables user attribution and collaborative tracking for shared shopping lists.
  final String? addedByUserId;

  /// Cached display name of the user who added this item for UI performance.
  /// Stored locally to avoid additional user profile lookups during item display.
  final String? addedByDisplayName;

  /// Timestamp when the item was originally added to the shopping list.
  /// Used for chronological tracking and collaborative audit trails.
  final DateTime? addedAt;

  /// User identifier of the person who purchased this item.
  /// Tracks who completed the purchase for collaborative shopping accountability.
  final String? purchasedByUserId;

  /// Cached display name of the user who purchased this item for UI performance.
  /// Stored locally to avoid additional user profile lookups during purchase display.
  final String? purchasedByDisplayName;

  /// Timestamp when the item was purchased.
  /// Records when the purchase was completed for collaborative tracking and analytics.
  final DateTime? purchasedAt;

  /// User identifier of the person who last modified this item.
  /// Tracks the most recent editor for collaborative change attribution.
  final String? lastModifiedByUserId;

  /// Cached display name of the user who last modified this item for UI performance.
  /// Stored locally to avoid additional user profile lookups during modification display.
  final String? lastModifiedByDisplayName;

  /// Timestamp when the item was last modified.
  /// Used for collaborative tracking and determining item freshness in shared lists.
  final DateTime? lastModifiedAt;

  /// Optional note or comment attached to the shopping item.
  /// Allows for additional context, specifications, or collaborative communication about the item.
  final String? note;

  /// Estimated price for the shopping item for budget planning.
  /// Optional pricing information for budget tracking and shopping cost estimation.
  final double? estimatedPrice;

  /// Priority level for the shopping item with range 1-5 where 5 is highest priority.
  /// Used for item organization and visual prioritization with emoji indicators.
  final int priority;

  /// Collaborative claim metadata — "I'll grab this one" (BUT-238).
  /// Distinct from [addedByUserId] (who added the item) and [purchasedByUserId]
  /// (who actually bought it). An assigned item is one a user has claimed
  /// responsibility for shopping; still purchasable by anyone with edit rights.

  /// User identifier of the person who has claimed ("tar jag") this item.
  /// Null when the item is unassigned.
  final String? assignedToUserId;

  /// Cached display name of the assignee for avatar/initials rendering.
  /// Stored locally to avoid user-profile lookups during list rendering.
  final String? assignedToDisplayName;

  /// Timestamp when the item was assigned. Null when unassigned.
  final DateTime? assignedAt;

  /// Creates a new unified shopping item with comprehensive metadata and automatic ID generation.
  /// This constructor provides complete shopping item initialization with support for both basic
  /// personal shopping and collaborative shared shopping experiences. All collaborative metadata
  /// is optional and defaults to null for basic shopping list usage.
  /// [id] Optional custom identifier, auto-generated UUID if not provided
  /// [name] Required item name for identification and display
  /// [amount] Required quantity amount with decimal precision support
  /// [unit] Unit of measurement, defaults to empty string for unitless items
  /// [category] Item category for organization, defaults to ShoppingCategory.other
  /// [bought] Purchase status, defaults to false for new items
  /// [addedByUserId] Optional user ID who added the item for collaborative tracking
  /// [addedByDisplayName] Optional display name for collaborative attribution
  /// [addedAt] Optional timestamp when item was added for audit trails
  /// [purchasedByUserId] Optional user ID who purchased the item for tracking
  /// [purchasedByDisplayName] Optional display name for purchase attribution
  /// [purchasedAt] Optional timestamp when item was purchased for analytics
  /// [lastModifiedByUserId] Optional user ID who last modified the item
  /// [lastModifiedByDisplayName] Optional display name for modification attribution
  /// [lastModifiedAt] Optional timestamp for last modification tracking
  /// [note] Optional note or comment for additional context
  /// [estimatedPrice] Optional price estimation for budget planning
  /// [priority] Priority level 1-5 where 5 is highest, defaults to 3 (medium)
  UnifiedShoppingItem({
    String? id,
    required this.name,
    required this.amount,
    this.unit = '',
    this.category = ShoppingCategory.other,
    this.bought = false,
    this.addedByUserId,
    this.addedByDisplayName,
    this.addedAt,
    this.purchasedByUserId,
    this.purchasedByDisplayName,
    this.purchasedAt,
    this.lastModifiedByUserId,
    this.lastModifiedByDisplayName,
    this.lastModifiedAt,
    this.note,
    this.estimatedPrice,
    this.priority = 3,
    this.assignedToUserId,
    this.assignedToDisplayName,
    this.assignedAt,
  }) : id = id ?? const Uuid().v4();

  /// Factory constructors for simplified shopping item creation with specific use cases.

  /// Creates a basic shopping item optimized for personal shopping lists.
  /// This factory provides simplified creation for non-collaborative shopping with minimal
  /// required parameters and no user attribution metadata. Ideal for personal shopping lists
  /// where collaborative tracking is not needed.
  /// [name] Required item name for identification and display
  /// [amount] Required quantity amount with decimal precision support
  /// [unit] Unit of measurement, defaults to empty string for unitless items
  /// [category] Item category for organization, defaults to ShoppingCategory.other
  /// [bought] Purchase status, defaults to false for new items
  /// Returns a new [UnifiedShoppingItem] with basic configuration and auto-generated ID.
  factory UnifiedShoppingItem.basic({
    required String name,
    required double amount,
    String unit = '',
    String category = ShoppingCategory.other,
    bool bought = false,
  }) {
    return UnifiedShoppingItem(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: bought,
    );
  }

  /// Creates a collaborative shopping item optimized for shared shopping lists.
  /// This factory provides comprehensive creation for collaborative shopping with full
  /// user attribution, timestamps, and enhanced metadata. Automatically sets up proper
  /// collaborative tracking with current timestamp initialization.
  /// [name] Required item name for identification and display
  /// [amount] Required quantity amount with decimal precision support
  /// [unit] Unit of measurement, defaults to empty string for unitless items
  /// [category] Item category for organization, defaults to ShoppingCategory.other
  /// [addedByUserId] Required user ID who added the item for attribution
  /// [addedByDisplayName] Required display name for collaborative UI display
  /// [note] Optional note or comment for additional context and communication
  /// [estimatedPrice] Optional price estimation for collaborative budget planning
  /// [priority] Priority level 1-5 where 5 is highest, defaults to 3 (medium)
  /// Returns a new [UnifiedShoppingItem] with collaborative configuration and current timestamps.
  factory UnifiedShoppingItem.collaborative({
    required String name,
    required double amount,
    String unit = '',
    String category = ShoppingCategory.other,
    required String addedByUserId,
    required String addedByDisplayName,
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) {
    final now = clock.now();
    return UnifiedShoppingItem(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: now,
      lastModifiedByUserId: addedByUserId,
      lastModifiedByDisplayName: addedByDisplayName,
      lastModifiedAt: now,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );
  }

  /// Creates a unified shopping item from legacy shopping item models for migration support.
  /// This factory provides backward compatibility with existing shopping item implementations
  /// by converting legacy models to the unified format. Safely handles missing fields with
  /// appropriate defaults for seamless migration.
  /// [oldItem] Legacy shopping item object with dynamic typing for flexible migration
  /// Returns a new [UnifiedShoppingItem] with basic configuration migrated from legacy data.
  factory UnifiedShoppingItem.fromShoppingItem(dynamic oldItem) {
    return UnifiedShoppingItem.basic(
      name: oldItem.name,
      amount: oldItem.amount,
      unit: oldItem.unit ?? '',
      category: oldItem.category ?? ShoppingCategory.other,
      bought: oldItem.bought ?? false,
    );
  }

  /// Smart formatting and utility methods for enhanced shopping item display and functionality.

  /// Checks if this shopping item has collaborative features enabled.
  /// Determines if the item was created with collaborative metadata by checking
  /// for the presence of user attribution information.
  /// Returns true if the item includes collaborative tracking data.
  bool get isCollaborative => addedByUserId != null;

  /// Checks if this shopping item has been purchased.
  /// Provides convenient access to purchase status for shopping list completion tracking.
  /// Returns true if the item has been marked as bought.
  bool get isPurchased => bought;

  /// Alias for purchase status for backward compatibility with legacy code.
  /// Provides compatibility with existing code that uses 'isCompleted' terminology.
  bool get isCompleted => bought;

  /// Alias for amount property for backward compatibility with legacy code.
  /// Provides compatibility with existing code that uses 'quantity' terminology.
  double get quantity => amount;

  /// Formats the item amount with intelligent decimal precision for optimal display.
  /// Implements smart formatting that removes unnecessary decimal places for whole numbers
  /// while preserving decimal precision when needed. Optimizes display text for better
  /// user experience and cleaner shopping list appearance.
  /// Returns formatted amount string without unnecessary decimal places.
  /// **Examples:**
  /// - 2.0 → "2"
  /// - 1.5 → "1.5"
  /// - 10.0 → "10"
  String get formattedAmount {
    // If it's a whole number, display without decimals
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }

    // Otherwise show with minimal precision
    return amount.toString();
  }

  /// Formats the item unit with Swedish abbreviations and mappings for optimal display.
  /// Implements intelligent unit formatting with comprehensive Swedish unit mapping system.
  /// Converts common long unit names to standard abbreviations while preserving
  /// user-friendly display for Swedish shopping contexts.
  /// Returns formatted unit string with appropriate Swedish abbreviations.
  /// **Swedish Unit Mappings:**
  /// - 'liter' → 'l'
  /// - 'styck'/'stycken' → 'st'
  /// - 'förpackning'/'förpackningar' → 'förp'
  /// - 'tesked'/'teskedar' → 'tsk'
  String get formattedUnit {
    if (unit.isEmpty) return '';

    // Map long unit names to short abbreviations for display
    final unitMappings = {
      'liter': 'l',
      'styck': 'st',
      'stycken': 'st',
      'förpackning': 'förp',
      'förpackningar': 'förp',
      'påse': 'påse',
      'påsar': 'påse',
      'burk': 'burk',
      'burkar': 'burk',
      'flaska': 'flaska',
      'flaskor': 'flaska',
      'bit': 'bit',
      'bitar': 'bit',
      'klyfta': 'klyfta',
      'klyftor': 'klyfta',
      'tesked': 'tsk',
      'teskedar': 'tsk',
    };

    return unitMappings[unit.toLowerCase()] ?? unit;
  }

  /// Generates optimized display text with intelligent formatting for Swedish shopping contexts.
  /// Implements sophisticated display logic that handles all common Swedish shopping scenarios
  /// with proper formatting, unit abbreviations, and quantity optimization. Provides natural
  /// language display text that matches Swedish shopping list conventions.
  /// Returns perfectly formatted display text for shopping list UI.
  /// **Display Format Examples:**
  /// - With unit: "1,5 l Mjölk", "2 st Ägg"
  /// - Without unit (quantity): "3 Bananer"
  /// - Single item: "Bröd" (when amount is 1.0 and no unit)
  String get displayText {
    final amountStr = formattedAmount;
    final unitStr = formattedUnit;

    // If amount is 0, show only the name (for ingredients that already have quantity)
    if (amount == 0.0) {
      return name;
    }

    // If we have a unit, show: "1,5 l Mjölk" or "2 st Ägg"
    if (unitStr.isNotEmpty) {
      return '$amountStr $unitStr $name';
    }

    // If only amount without unit: "3 Bananer"
    if (amount != 1.0) {
      return '$amountStr $name';
    }

    // If amount is 1 without unit, show only the name: "Bröd"
    return name;
  }

  /// Gets the emoji representation for the item's priority level.
  /// Provides visual priority indicators with color-coded emoji system for quick
  /// priority identification in shopping lists. Maps priority numbers to intuitive
  /// emoji representations for enhanced user experience.
  /// Returns priority emoji based on priority level (1-5 scale).
  /// **Priority Emoji Mapping:**
  /// - 5 (Highest): 🔴 (Red circle)
  /// - 4 (High): 🟠 (Orange circle)
  /// - 3 (Medium): 🟡 (Yellow circle)
  /// - 2 (Low): 🟢 (Green circle)
  /// - 1 (Lowest): ⚪ (White circle)
  String get priorityEmoji {
    switch (priority) {
      case 5:
        return '🔴'; // Highest
      case 4:
        return '🟠'; // High
      case 3:
        return '🟡'; // Medium
      case 2:
        return '🟢'; // Low
      case 1:
        return '⚪'; // Lowest
      default:
        return '🟡';
    }
  }

  /// Update methods for shopping item modification with collaborative tracking support.

  /// Creates a copy of this shopping item with updated values while preserving immutability.
  /// Used for all item modifications while maintaining immutable data patterns and ensuring
  /// consistent state management for collaborative tracking. Automatically updates modification
  /// timestamps and user attribution when collaborative metadata is provided.
  /// Returns a new [UnifiedShoppingItem] instance with updated values.
  ///
  /// [clearNote] erases the note. A bare `note: null` cannot mean that — the
  /// same value already means "leave it alone" — so removing a note needs its
  /// own signal, as on [PantryItem.copyWith].
  UnifiedShoppingItem copyWith({
    String? name,
    double? amount,
    String? unit,
    String? category,
    bool? bought,
    String? note,
    bool clearNote = false,
    double? estimatedPrice,
    int? priority,
    String? lastModifiedByUserId,
    String? lastModifiedByDisplayName,
    DateTime? lastModifiedAt,
  }) {
    // Effective bought state — copyWith callers editing an already-bought
    // item's name/amount don't pass `bought`, so keying purchase attribution
    // off the raw `bought` param wiped purchasedBy*/purchasedAt on every edit.
    final effectiveBought = bought ?? this.bought;
    // Only a genuine not-bought → bought transition (re)stamps the buyer/time;
    // edits to an already-bought item preserve the original attribution.
    final becameBought = bought == true && !this.bought;
    return UnifiedShoppingItem(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      bought: effectiveBought,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: addedAt,
      purchasedByUserId: effectiveBought
          ? (becameBought
                ? (lastModifiedByUserId ?? purchasedByUserId)
                : purchasedByUserId)
          : null,
      purchasedByDisplayName: effectiveBought
          ? (becameBought
                ? (lastModifiedByDisplayName ?? purchasedByDisplayName)
                : purchasedByDisplayName)
          : null,
      purchasedAt: effectiveBought
          ? (becameBought ? clock.now() : purchasedAt)
          : null,
      lastModifiedByUserId: lastModifiedByUserId ?? this.lastModifiedByUserId,
      lastModifiedByDisplayName:
          lastModifiedByDisplayName ?? this.lastModifiedByDisplayName,
      lastModifiedAt: lastModifiedAt ?? clock.now(),
      note: clearNote ? null : (note ?? this.note),
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      priority: priority ?? this.priority,
      assignedToUserId: assignedToUserId,
      assignedToDisplayName: assignedToDisplayName,
      assignedAt: assignedAt,
    );
  }

  /// Claims the item for a user — "Tar jag" / "I'll get this" (BUT-238).
  /// Returns a new instance with [assignedToUserId], [assignedToDisplayName],
  /// and [assignedAt] populated plus `lastModifiedBy*` synced to the claimer.
  /// Note: service layer should use atomic Firestore `update` on these fields
  /// to avoid lost-update races — see `CollaborativeShoppingViewModel.claimItem`.
  UnifiedShoppingItem assign({
    required String userId,
    required String displayName,
  }) {
    final now = clock.now();
    return UnifiedShoppingItem(
      id: id,
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: bought,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: addedAt,
      purchasedByUserId: purchasedByUserId,
      purchasedByDisplayName: purchasedByDisplayName,
      purchasedAt: purchasedAt,
      lastModifiedByUserId: userId,
      lastModifiedByDisplayName: displayName,
      lastModifiedAt: now,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
      assignedToUserId: userId,
      assignedToDisplayName: displayName,
      assignedAt: now,
    );
  }

  /// Releases the claim — "Lämna tillbaka" / "Give back" (BUT-238).
  /// Returns a new instance with assignment fields cleared. Caller-provided
  /// [userId] / [displayName] stamp `lastModifiedBy*` for audit trail; when
  /// omitted, existing modification metadata is preserved.
  UnifiedShoppingItem unassign({
    String? userId,
    String? displayName,
  }) {
    final now = clock.now();
    return UnifiedShoppingItem(
      id: id,
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: bought,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: addedAt,
      purchasedByUserId: purchasedByUserId,
      purchasedByDisplayName: purchasedByDisplayName,
      purchasedAt: purchasedAt,
      lastModifiedByUserId: userId ?? lastModifiedByUserId,
      lastModifiedByDisplayName: displayName ?? lastModifiedByDisplayName,
      lastModifiedAt: now,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
      assignedToUserId: null,
      assignedToDisplayName: null,
      assignedAt: null,
    );
  }

  /// True when this item is currently claimed by some user.
  bool get isAssigned => assignedToUserId != null;

  /// Toggles the purchased status of the shopping item with collaborative user tracking.
  /// Implements purchase status toggle functionality with automatic collaborative metadata
  /// updates including user attribution and timestamp management for shared shopping lists.
  /// [userId] Optional user ID for collaborative purchase attribution
  /// [userDisplayName] Optional display name for collaborative purchase tracking
  /// Returns a new [UnifiedShoppingItem] with toggled purchase status and updated metadata.
  UnifiedShoppingItem togglePurchased({
    String? userId,
    String? userDisplayName,
  }) {
    final now = clock.now();
    final newBought = !bought;

    return UnifiedShoppingItem(
      id: id,
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: newBought,
      addedByUserId: addedByUserId,
      addedByDisplayName: addedByDisplayName,
      addedAt: addedAt,
      purchasedByUserId: newBought ? userId : null,
      purchasedByDisplayName: newBought ? userDisplayName : null,
      purchasedAt: newBought ? now : null,
      lastModifiedByUserId: userId ?? lastModifiedByUserId,
      lastModifiedByDisplayName: userDisplayName ?? lastModifiedByDisplayName,
      lastModifiedAt: now,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
      assignedToUserId: assignedToUserId,
      assignedToDisplayName: assignedToDisplayName,
      assignedAt: assignedAt,
    );
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the shopping item to JSON format for caching and client-side storage.
  /// Provides JSON serialization for client-side caching, local storage, and data transfer
  /// with ISO timestamp formatting and complete collaborative metadata serialization.
  /// Returns a JSON-compatible map with all shopping item data properly formatted.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category,
      'bought': bought,
      'addedByUserId': addedByUserId,
      'addedByDisplayName': addedByDisplayName,
      'addedAt': addedAt?.toIso8601String(),
      'purchasedByUserId': purchasedByUserId,
      'purchasedByDisplayName': purchasedByDisplayName,
      'purchasedAt': purchasedAt?.toIso8601String(),
      'lastModifiedByUserId': lastModifiedByUserId,
      'lastModifiedByDisplayName': lastModifiedByDisplayName,
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'note': note,
      'estimatedPrice': estimatedPrice,
      'priority': priority,
      'assignedToUserId': assignedToUserId,
      'assignedToDisplayName': assignedToDisplayName,
      'assignedAt': assignedAt?.toIso8601String(),
    };
  }

  /// Converts the shopping item to Firestore-compatible format for persistence.
  /// Transforms all shopping item data into Firestore format with proper timestamp handling
  /// and collaborative metadata serialization for efficient database storage and retrieval.
  /// Returns a map containing all shopping item data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category,
      'bought': bought,
      'addedByUserId': addedByUserId,
      'addedByDisplayName': addedByDisplayName,
      'addedAt': addedAt != null ? Timestamp.fromDate(addedAt!) : null,
      'purchasedByUserId': purchasedByUserId,
      'purchasedByDisplayName': purchasedByDisplayName,
      'purchasedAt': purchasedAt != null
          ? Timestamp.fromDate(purchasedAt!)
          : null,
      'lastModifiedByUserId': lastModifiedByUserId,
      'lastModifiedByDisplayName': lastModifiedByDisplayName,
      'lastModifiedAt': lastModifiedAt != null
          ? Timestamp.fromDate(lastModifiedAt!)
          : null,
      'note': note,
      'estimatedPrice': estimatedPrice,
      'priority': priority,
      'assignedToUserId': assignedToUserId,
      'assignedToDisplayName': assignedToDisplayName,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
    };
  }

  /// Creates a shopping item instance from JSON data for caching and deserialization.
  /// Transforms JSON cache data into a complete [UnifiedShoppingItem] instance with proper
  /// type conversion and collaborative metadata deserialization for client-side caching support.
  /// [json] JSON data containing all shopping item fields and collaborative metadata
  /// Returns a new [UnifiedShoppingItem] instance with all data properly parsed from JSON.
  factory UnifiedShoppingItem.fromJson(Map<String, dynamic> json) {
    return UnifiedShoppingItem(
      id: SerializationUtils.safeString(json, 'id'),
      name: SerializationUtils.safeString(json, 'name'),
      amount: SerializationUtils.safeDouble(json, 'amount'),
      unit: SerializationUtils.safeString(json, 'unit'),
      category: SerializationUtils.safeString(
        json,
        'category',
        defaultValue: ShoppingCategory.other,
      ),
      bought: SerializationUtils.safeBool(json, 'bought'),
      addedByUserId: SerializationUtils.safeNullableString(
        json,
        'addedByUserId',
      ),
      addedByDisplayName: SerializationUtils.safeNullableString(
        json,
        'addedByDisplayName',
      ),
      addedAt: SerializationUtils.safeDateTime(json, 'addedAt'),
      purchasedByUserId: SerializationUtils.safeNullableString(
        json,
        'purchasedByUserId',
      ),
      purchasedByDisplayName: SerializationUtils.safeNullableString(
        json,
        'purchasedByDisplayName',
      ),
      purchasedAt: SerializationUtils.safeDateTime(json, 'purchasedAt'),
      lastModifiedByUserId: SerializationUtils.safeNullableString(
        json,
        'lastModifiedByUserId',
      ),
      lastModifiedByDisplayName: SerializationUtils.safeNullableString(
        json,
        'lastModifiedByDisplayName',
      ),
      lastModifiedAt: SerializationUtils.safeDateTime(json, 'lastModifiedAt'),
      note: SerializationUtils.safeNullableString(json, 'note'),
      estimatedPrice: SerializationUtils.safeNullableDouble(
        json,
        'estimatedPrice',
      ),
      priority: SerializationUtils.safeInt(json, 'priority', defaultValue: 3),
      assignedToUserId: SerializationUtils.safeNullableString(
        json,
        'assignedToUserId',
      ),
      assignedToDisplayName: SerializationUtils.safeNullableString(
        json,
        'assignedToDisplayName',
      ),
      assignedAt: SerializationUtils.safeDateTime(json, 'assignedAt'),
    );
  }

  /// Creates a shopping item instance from Firestore repository data with robust parsing.
  /// Transforms Firestore document data into a complete [UnifiedShoppingItem] instance with proper
  /// type conversion, timestamp parsing, and collaborative metadata deserialization for
  /// robust data recovery from database storage.
  /// [data] Raw Firestore data containing all shopping item fields
  /// Returns a new [UnifiedShoppingItem] instance with all data properly parsed from Firestore.
  factory UnifiedShoppingItem.fromFirestore(Map<String, dynamic> data) {
    return UnifiedShoppingItem(
      id: SerializationUtils.safeString(data, 'id'),
      name: SerializationUtils.safeString(data, 'name'),
      amount: SerializationUtils.safeDouble(data, 'amount'),
      unit: SerializationUtils.safeString(data, 'unit'),
      category: SerializationUtils.safeString(
        data,
        'category',
        defaultValue: ShoppingCategory.other,
      ),
      bought: SerializationUtils.safeBool(data, 'bought'),
      addedByUserId: SerializationUtils.safeNullableString(
        data,
        'addedByUserId',
      ),
      addedByDisplayName: SerializationUtils.safeNullableString(
        data,
        'addedByDisplayName',
      ),
      addedAt: SerializationUtils.safeDateTime(data, 'addedAt'),
      purchasedByUserId: SerializationUtils.safeNullableString(
        data,
        'purchasedByUserId',
      ),
      purchasedByDisplayName: SerializationUtils.safeNullableString(
        data,
        'purchasedByDisplayName',
      ),
      purchasedAt: SerializationUtils.safeDateTime(data, 'purchasedAt'),
      lastModifiedByUserId: SerializationUtils.safeNullableString(
        data,
        'lastModifiedByUserId',
      ),
      lastModifiedByDisplayName: SerializationUtils.safeNullableString(
        data,
        'lastModifiedByDisplayName',
      ),
      lastModifiedAt: SerializationUtils.safeDateTime(data, 'lastModifiedAt'),
      note: SerializationUtils.safeNullableString(data, 'note'),
      estimatedPrice: SerializationUtils.safeNullableDouble(
        data,
        'estimatedPrice',
      ),
      priority: SerializationUtils.safeInt(data, 'priority', defaultValue: 3),
      assignedToUserId: SerializationUtils.safeNullableString(
        data,
        'assignedToUserId',
      ),
      assignedToDisplayName: SerializationUtils.safeNullableString(
        data,
        'assignedToDisplayName',
      ),
      assignedAt: SerializationUtils.safeDateTime(data, 'assignedAt'),
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns the optimized display text for string representation.
  /// Provides the formatted display text as the string representation for debugging
  /// and logging purposes, using the intelligent formatting system.
  @override
  String toString() => displayText;

  /// Compares two shopping items for equality based on unique identifier.
  /// Uses item ID for equality comparison ensuring consistent object identity
  /// across different instances of the same shopping item data.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedShoppingItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// Generates hash code based on unique shopping item identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and item identification.
  @override
  int get hashCode => id.hashCode;
}
