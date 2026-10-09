import 'package:flutter/widgets.dart' show StringCharacters;

List<String> _words(String name) =>
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

String initialsFor(String name) {
  final words = _words(name);
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return (words.first.characters.first + words.last.characters.first)
      .toUpperCase();
}

/// Initials for every name in [names], same order. Only names that would
/// otherwise look identical to a different person get longer initials, so
/// a lone "Anna Berg" stays "AB". Escalates "Ma"/"Mi" (two letters of the
/// first name), then first letter plus the first character where the full
/// names differ ("T6"/"T7"). Identical names keep identical initials.
List<String> distinctInitials(List<String> names) {
  // Case-folded so "anna berg" and "Anna Berg" count as one person.
  final keys = [for (final n in names) _words(n).join(' ').toLowerCase()];
  final result = [for (final n in names) initialsFor(n)];

  for (final group in _collidingGroups(keys, result)) {
    for (final i in group) {
      final first = _words(names[i]).first.characters;
      if (first.length < 2) continue;
      result[i] = first.first.toUpperCase() + first.elementAt(1).toLowerCase();
    }
  }

  // Entries without a second letter keep their plain initials and are
  // regrouped with the rest here, so they still reach the last step. A
  // subgroup that still agrees at that character ("Anna Berg" and
  // "Anna Bergström" beside "Anna Björk") is split again on its own next
  // difference.
  // Bounded because a relabelled group can land on another group's label
  // and the two would regroup.
  var changed = true;
  for (var round = 0; changed && round < names.length; round++) {
    changed = false;
    for (final group in _collidingGroups(keys, result).toList()) {
      final chars = [for (final i in group) keys[i].characters];
      var d = 0;
      while (chars.every((c) => d < c.length) &&
          chars.every((c) => c.elementAt(d) == chars.first.elementAt(d))) {
        d++;
      }
      for (var g = 0; g < group.length; g++) {
        final i = group[g];
        // A space is no letter to show, so take the next one after it.
        final diff = chars[g]
            .skip(d)
            .firstWhere((c) => c.trim().isNotEmpty, orElse: () => '');
        final label =
            _words(names[i]).first.characters.first.toUpperCase() +
            diff.toUpperCase();
        if (label != result[i]) changed = true;
        result[i] = label;
      }
    }
  }
  return result;
}

/// Groups of indices sharing the same [labels] value but at least two
/// different names; identical names are one person and never collide.
Iterable<List<int>> _collidingGroups(List<String> keys, List<String> labels) {
  final byLabel = <String, List<int>>{};
  for (var i = 0; i < keys.length; i++) {
    if (keys[i].isEmpty) continue;
    byLabel.putIfAbsent(labels[i], () => []).add(i);
  }
  return byLabel.values.where(
    (g) => g.map((i) => keys[i]).toSet().length > 1,
  );
}
