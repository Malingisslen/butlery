// BUT-2529: the week menu's saved wishes and last week's wish, stored on
// `users/{uid}/settings/preferences` beside the fixed-day rules.
library;

/// A wish the user saved for a later week: [name] is the short chip text,
/// [text] what goes into the prompt field.
class MenuWish {
  const MenuWish({required this.id, required this.name, required this.text});

  final String id;
  final String name;
  final String text;

  /// Null for a row a hand-written document or an older app could leave
  /// behind: no id, no text, or the wrong types.
  static MenuWish? fromFirestore(Map<String, dynamic> data) {
    final id = data['id'];
    final text = data['text'];
    if (id is! String || id.isEmpty || id.length > MenuWishes.maxIdLength) {
      return null;
    }
    if (text is! String) return null;
    final cleanText = MenuWishes.clampText(text);
    if (cleanText.isEmpty) return null;
    final name = data['name'];
    final cleanName = name is String ? MenuWishes.clampName(name) : '';
    return MenuWish(
      id: id,
      name: cleanName.isEmpty ? MenuWishes.nameFor(cleanText) : cleanName,
      text: cleanText,
    );
  }

  Map<String, dynamic> toFirestore() => {'id': id, 'name': name, 'text': text};

  MenuWish copyWith({String? name}) =>
      MenuWish(id: id, name: name ?? this.name, text: text);

  @override
  bool operator ==(Object other) =>
      other is MenuWish &&
      other.id == id &&
      other.name == name &&
      other.text == text;

  @override
  int get hashCode => Object.hash(id, name, text);
}

/// The wish the last menu was generated from, offered as "Som förra veckan".
class LastMenuWish {
  const LastMenuWish({required this.text, this.pantryFocus = false});

  final String text;
  final bool pantryFocus;

  static const String field = 'lastMenuWish';

  static LastMenuWish? fromFirestore(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String) return null;
    final clean = MenuWishes.clampText(text);
    if (clean.isEmpty) return null;
    return LastMenuWish(text: clean, pantryFocus: raw['pantryFocus'] == true);
  }

  Map<String, dynamic> toFirestore() => {
    'text': text,
    'pantryFocus': pantryFocus,
  };

  /// Whether generating from [text] with [pantryFocus] would store anything
  /// new; same wish, no write.
  bool sameAs(String text, {required bool pantryFocus}) =>
      this.text == MenuWishes.clampText(text) &&
      this.pantryFocus == pantryFocus;

  @override
  bool operator ==(Object other) =>
      other is LastMenuWish &&
      other.text == text &&
      other.pantryFocus == pantryFocus;

  @override
  int get hashCode => Object.hash(text, pantryFocus);
}

/// The saved-wish list as stored. firestore.rules bounds the list at
/// [maxWishes] and the last wish's text at [maxTextLength].
abstract final class MenuWishes {
  static const int maxWishes = 12;
  static const int maxTextLength = 300;
  static const int maxNameLength = 40;
  static const int maxIdLength = 64;

  static const String field = 'savedMenuWishes';

  /// Reads the stored list as untrusted input: rows that do not parse are
  /// skipped, a repeated id keeps its first row, and the list is cut at
  /// [maxWishes].
  static List<MenuWish> fromFirestoreList(Object? raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final wishes = <MenuWish>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final wish = MenuWish.fromFirestore(Map<String, dynamic>.from(row));
      if (wish == null || !seen.add(wish.id)) continue;
      wishes.add(wish);
      if (wishes.length == maxWishes) break;
    }
    return List.unmodifiable(wishes);
  }

  static List<Map<String, dynamic>> toFirestoreList(List<MenuWish> wishes) => [
    for (final w in wishes) w.toFirestore(),
  ];

  static String clampText(String text) => _clamp(text.trim(), maxTextLength);

  static String clampName(String name) => _clamp(name.trim(), maxNameLength);

  /// A chip name from the wish text: the text itself when it fits, else
  /// cut at the last word break that fits, with an ellipsis.
  static String nameFor(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= maxNameLength) return clean;
    final cut = clean.substring(0, maxNameLength - 1);
    final space = cut.lastIndexOf(' ');
    final head = space > maxNameLength ~/ 2 ? cut.substring(0, space) : cut;
    return '${head.trimRight()}…';
  }

  /// Whether [text] is already one of [wishes], ignoring case and spacing.
  static bool contains(List<MenuWish> wishes, String text) {
    final key = _key(text);
    return wishes.any((w) => _key(w.text) == key);
  }

  /// [wishes] with a new wish for [text] at the front. Null when the list is
  /// full or the text is empty or already saved.
  static List<MenuWish>? add(
    List<MenuWish> wishes,
    String text, {
    required String id,
  }) {
    final clean = clampText(text);
    if (clean.isEmpty || contains(wishes, clean)) return null;
    if (wishes.length >= maxWishes) return null;
    return List.unmodifiable([
      MenuWish(id: id, name: nameFor(clean), text: clean),
      ...wishes,
    ]);
  }

  /// Null when [name] is empty after trimming or [id] is not in the list.
  static List<MenuWish>? rename(List<MenuWish> wishes, String id, String name) {
    final clean = clampName(name);
    final index = wishes.indexWhere((w) => w.id == id);
    if (clean.isEmpty || index < 0) return null;
    return List.unmodifiable(
      [...wishes]..[index] = wishes[index].copyWith(name: clean),
    );
  }

  static List<MenuWish> remove(List<MenuWish> wishes, String id) =>
      List.unmodifiable(wishes.where((w) => w.id != id));

  /// [wishes] with [wish] back at [index], for Ångra.
  static List<MenuWish> restore(
    List<MenuWish> wishes,
    MenuWish wish,
    int index,
  ) {
    if (wishes.any((w) => w.id == wish.id)) return wishes;
    final at = index.clamp(0, wishes.length);
    return List.unmodifiable([...wishes]..insert(at, wish));
  }

  static String _key(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _clamp(String s, int max) {
    if (s.length <= max) return s;
    // Never split a surrogate pair at the cut.
    var end = max;
    final unit = s.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end--;
    return s.substring(0, end);
  }
}
