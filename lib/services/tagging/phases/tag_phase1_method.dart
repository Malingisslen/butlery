/// Cooking method and dish type tag calculation for Phase 1.
class Phase1MethodCalculator {
  /// Calculates cooking method tags from instructions.
  ///
  /// Uses word boundary matching to avoid false positives from substrings.
  /// Normalizes dashes/underscores for consistent matching.
  static Set<String> calculateCookingMethodTags(List<String> instructions) {
    final tags = <String>{};
    final text = instructions
        .join(' ')
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '');

    // Matches word at start boundary only, allowing Swedish suffixes
    // (e.g., "grilla"/"grillad"/"grillar" all match "grill").
    // Intentionally different from TagPhase1Base.containsSwedishWord which
    // checks both boundaries — here we need suffix flexibility.
    bool hasWord(String word) {
      final pattern = RegExp('(?:^|[^a-zåäö])$word', caseSensitive: false);
      return pattern.hasMatch(text);
    }

    if ((hasWord('ugn') || text.contains('°c') || hasWord('grader')) &&
        !hasWord('mikro') &&
        !hasWord('micro')) {
      tags.add('ugnsbakad');
    }

    if (hasWord('stek') || hasWord('bryn')) tags.add('stekt');
    if (hasWord('grill')) tags.add('grillad');

    if (hasWord('koka') ||
        (hasWord('kok') && !text.contains('kokos')) ||
        hasWord('sjud')) {
      tags.add('kokt');
    }

    if (hasWord('ångkok') || hasWord('ånga')) tags.add('ångkokt');
    if (hasWord('pochera') || hasWord('pocherad')) tags.add('pocherad');
    if (hasWord('fritera') || hasWord('friterad') || hasWord('fritering')) {
      tags.add('friterad');
    }

    if (text.contains('airfryer') || text.contains('air fryer')) {
      tags.add('airfryer');
    }
    if (text.contains('slow cooker') || text.contains('crock pot')) {
      tags.add('slow-cooker');
    }
    if (hasWord('tryckkokare') || text.contains('instant pot')) {
      tags.add('tryckkokare');
    }
    if (text.contains('sous vide') || text.contains('sous-vide')) {
      tags.add('sous-vide');
    }
    if (hasWord('wok')) tags.add('wokad');
    if (hasWord('micro') || hasWord('mikro')) tags.add('microugn');
    if (hasWord('rök') && !hasWord('röra') && !hasWord('rörelse')) {
      tags.add('rökt');
    }

    return tags;
  }

  /// Calculates dish type tags from recipe title.
  static Set<String> calculateDishTypeTags(String title) {
    final tags = <String>{};
    final titleLower = title.toLowerCase();

    const dishTypes = {
      'soppa': ['soppa', 'buljong'],
      'sallad': ['sallad'],
      'gryta': ['gryta'],
      'gratäng': ['gratäng'],
      'curry': ['curry'],
      'smörgås': ['smörgås', 'macka'],
      'hamburgare': ['hamburgare', 'burger'],
      'pizza': ['pizza'],
      'taco': ['taco', 'tacos'],
      'bowl': ['bowl', 'poké', 'poke'],
      'paj': ['paj', 'pie', 'quiche'],
      'kaka': ['kaka', 'tårta'],
      'bröd': ['bröd'],
      'köttbullar': ['köttbull'],
      'omelett': ['omelett'],
      'pannkaka': ['pannkak', 'crêpe', 'crepe'],
      'våffla': ['våffl'],
      'smoothie': ['smoothie'],
      'wok': ['wok'],
      'dipp': ['dipp', 'dip'],
      'sås': ['sås'],
    };

    for (final entry in dishTypes.entries) {
      for (final keyword in entry.value) {
        if (titleLower.contains(keyword)) {
          if (entry.key == 'kaka' && titleLower.contains('pannkak')) {
            continue;
          }
          tags.add(entry.key);
          break;
        }
      }
    }

    return tags;
  }
}
