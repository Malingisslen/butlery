import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';

/// Phase 4: Mood and occasion tags requiring all previous phases.
///
/// Generates:
/// - Time-based occasions (weeknight, weekend, quick-fix)
/// - Mood tags (comfort-food, warming, refreshing)
/// - Swedish holidays (christmas, midsummer, easter)
/// - Seasons (spring, summer, autumn, winter)
class TagPhase4Mood {
  /// Calculates Phase 4 tags.
  Phase4Result calculate(
    Phase1Result p1,
    Phase2Result p2,
    Phase3Result p3,
    Recipe recipe,
  ) {
    final tags = <String>{};

    // Time-based occasions
    tags.addAll(_calculateTimeBasedTags(p1, p3, recipe));

    // Mood tags
    tags.addAll(_calculateMoodTags(p1, p2, p3, recipe));

    // Swedish holidays
    tags.addAll(_calculateSwedishHolidayTags(p1, recipe));

    // Seasons
    tags.addAll(_calculateSeasonTags(p1));

    return Phase4Result(
      tags: tags,
      phase1: p1,
      phase2: p2,
      phase3: p3,
    );
  }

  Set<String> _calculateTimeBasedTags(
    Phase1Result p1,
    Phase3Result p3,
    Recipe recipe,
  ) {
    final tags = <String>{};
    final time = recipe.core.timeMinutes ?? 30;

    // Weeknight: under 45 min AND easy/medium
    if (p1.hasTag('under-45-min') &&
        (p3.hasTag('enkel') || p3.hasTag('medel'))) {
      tags.add('vardagsmiddag');
    }

    // Weekend: medium/advanced OR longer cooking
    if (p3.hasTag('medel') || p3.hasTag('avancerad') || time > 60) {
      tags.add('helgmat');
    }

    // Dinner party: advanced OR luxury ingredients
    if (p3.hasTag('avancerad') || _hasLuxuryIngredients(p1)) {
      tags.add('middagsbjudning');
    }

    // Quick fix: under 15 min AND easy
    if (p1.hasTag('under-15-min') && p3.hasTag('enkel')) {
      tags.add('snabblagat');
    }

    // Friday night
    if (p1.hasTag('taco') ||
        p1.hasTag('pizza') ||
        p1.hasTag('hamburgare') ||
        recipe.core.title.toLowerCase().contains('nachos')) {
      tags.add('fredagsmys');
    }

    // Sunday dinner
    if (time > 60 && (p1.hasTag('gryta') || p1.hasTag('ugnsbakad'))) {
      tags.add('söndagsmiddag');
    }

    return tags;
  }

  Set<String> _calculateMoodTags(
    Phase1Result p1,
    Phase2Result p2,
    Phase3Result p3,
    Recipe recipe,
  ) {
    final tags = <String>{};

    // Comfort food: creamy AND (pasta OR potato OR rice)
    if (p3.hasTag('krämig') &&
        (p1.hasTag('pastabaserad') ||
            p1.hasTag('potatisbaserad') ||
            p1.hasTag('risbaserad'))) {
      tags.add('comfort-food');
    }

    // Warming: soup OR stew OR hot + spiced
    if (p1.hasTag('soppa') || p1.hasTag('gryta')) {
      tags.add('värmande');
    }

    // Refreshing: salad OR cold + citrus
    if (p1.hasTag('sallad') ||
        (p3.hasTag('kall-rätt') && p1.lookup.hasGroup('fruit/citrus'))) {
      tags.add('fräsch');
    }

    // Luxurious: premium ingredients
    if (_hasLuxuryIngredients(p1)) {
      tags.add('lyxig');
    }

    return tags;
  }

  Set<String> _calculateSwedishHolidayTags(Phase1Result p1, Recipe recipe) {
    final tags = <String>{};
    final title = recipe.core.title.toLowerCase();

    // Christmas (Jul)
    final christmasKeywords = ['julskinka', 'lutfisk', 'jansson', 'julbord'];
    if (title.contains('jul') ||
        christmasKeywords.any((k) => title.contains(k)) ||
        _hasChristmasIngredients(p1)) {
      tags.add('jul');
    }

    // Lucia
    if (title.contains('lucia') ||
        title.contains('lussebulle') ||
        title.contains('lussekatt')) {
      tags.add('lucia');
    }

    // Easter (Påsk)
    if (title.contains('påsk') || _hasEasterIngredients(p1, title)) {
      tags.add('påsk');
    }

    // Midsummer (Midsommar)
    if (title.contains('midsommar') || _hasMidsummerIngredients(p1)) {
      tags.add('midsommar');
    }

    // Crayfish party (Kräftskiva)
    if (title.contains('kräftskiva') ||
        title.contains('kräftkalas') ||
        _hasCrawfishIngredients(p1)) {
      tags.add('kräftskiva');
    }

    // New Year's (Nyår)
    if (title.contains('nyår') || _hasNewYearsIngredients(p1)) {
      tags.add('nyår');
    }

    return tags;
  }

  Set<String> _calculateSeasonTags(Phase1Result p1) {
    final tags = <String>{};

    // Spring: asparagus, rhubarb, new vegetables
    if (_hasSpringIngredients(p1)) {
      tags.add('vår');
    }

    // Summer: strawberries, grilled, fresh salads
    if (_hasSummerIngredients(p1)) {
      tags.add('sommar');
    }

    // Autumn: mushrooms, apples, game
    if (_hasAutumnIngredients(p1)) {
      tags.add('höst');
    }

    // Winter: root vegetables, cabbage, slow-cooked
    if (_hasWinterIngredients(p1)) {
      tags.add('vinter');
    }

    // Note: No 'året-runt' default tag - absence of season tags already
    // indicates year-round suitability. Adding it would be meaningless noise.

    return tags;
  }

  bool _hasLuxuryIngredients(Phase1Result p1) {
    final luxuryKeywords = [
      'oxfilé',
      'entrecôte',
      'hummer',
      'kräftor',
      'tryffel',
      'kaviar',
      'foie gras',
      'wagyu',
      'kalvfilé',
    ];

    return p1.lookup.matched.any((i) {
      final name = i.swedish.toLowerCase();
      return luxuryKeywords.any((k) => name.contains(k));
    });
  }

  bool _hasChristmasIngredients(Phase1Result p1) {
    final christmasIngredients = [
      'rödbeta',
      'sill',
      'julkorv',
      'prinskorv',
      'kål',
    ];

    final matchCount = p1.lookup.matched.where((i) {
      final name = i.swedish.toLowerCase();
      return christmasIngredients.any((k) => name.contains(k));
    }).length;

    return matchCount >= 2;
  }

  bool _hasEasterIngredients(Phase1Result p1, String title) {
    // Lamb as main OR egg dishes
    return (p1.hasTag('lamm') ||
        (p1.hasTag('ägg') && (title.contains('ägg') || title.contains('egg'))));
  }

  bool _hasMidsummerIngredients(Phase1Result p1) {
    final hasSill =
        p1.lookup.matched.any((i) => i.swedish.toLowerCase().contains('sill'));
    final hasNewPotatoes = p1.lookup.matched.any((i) =>
        i.swedish.toLowerCase().contains('färskpotatis') ||
        i.swedish.toLowerCase().contains('nypotatis'));
    final hasStrawberries = p1.lookup.matched
        .any((i) => i.swedish.toLowerCase().contains('jordgubb'));

    return (hasSill && hasNewPotatoes) ||
        (hasStrawberries && p1.hasProperty('dairy'));
  }

  bool _hasCrawfishIngredients(Phase1Result p1) {
    return p1.lookup.matched
        .any((i) => i.swedish.toLowerCase().contains('kräft'));
  }

  bool _hasNewYearsIngredients(Phase1Result p1) {
    final luxurySeafood = ['hummer', 'ostron', 'kaviar'];
    return p1.lookup.matched.any((i) {
      final name = i.swedish.toLowerCase();
      return luxurySeafood.any((k) => name.contains(k));
    });
  }

  bool _hasSpringIngredients(Phase1Result p1) {
    final springIngredients = ['sparris', 'rabarber', 'rädisor', 'vårlök'];
    return p1.lookup.matched.any((i) {
      final name = i.swedish.toLowerCase();
      return springIngredients.any((k) => name.contains(k));
    });
  }

  bool _hasSummerIngredients(Phase1Result p1) {
    final summerIngredients = [
      'jordgubb',
      'hallon',
      'blåbär',
      'sallad',
      'gurka'
    ];
    final matchCount = p1.lookup.matched.where((i) {
      final name = i.swedish.toLowerCase();
      return summerIngredients.any((k) => name.contains(k));
    }).length;
    return matchCount >= 2 || p1.hasTag('grillad');
  }

  bool _hasAutumnIngredients(Phase1Result p1) {
    final autumnIngredients = ['svamp', 'kantarell', 'äpple', 'pumpa', 'kål'];
    return p1.lookup.matched.any((i) {
          final name = i.swedish.toLowerCase();
          return autumnIngredients.any((k) => name.contains(k));
        }) ||
        p1.hasTag('vilt');
  }

  bool _hasWinterIngredients(Phase1Result p1) {
    final winterIngredients = ['rotfrukt', 'morot', 'palsternacka', 'kålrot'];
    final matchCount = p1.lookup.matched.where((i) {
      final name = i.swedish.toLowerCase();
      return winterIngredients.any((k) => name.contains(k));
    }).length;
    return matchCount >= 2;
  }
}

/// Result of Phase 4 calculation.
class Phase4Result {
  final Set<String> tags;
  final Phase1Result phase1;
  final Phase2Result phase2;
  final Phase3Result phase3;

  const Phase4Result({
    required this.tags,
    required this.phase1,
    required this.phase2,
    required this.phase3,
  });

  /// Gets all tags from all phases combined.
  Set<String> get allTags => {
        ...phase1.tags,
        ...phase2.tags,
        ...phase3.tags,
        ...tags,
      };
}
