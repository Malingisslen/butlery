/// Hostname → coarse bucket mapping for parse-tier analytics (BUT-552).
///
/// Raw hostnames are cardinality bombs in Firebase Analytics — every
/// long-tail blog domain becomes its own dimension value and analyses
/// over millions of imports become unusable. We bucket aggressively into
/// known major recipe sites + an `other` catch-all.
///
/// To add a new platform: add an entry to [_knownPlatforms] keyed by the
/// bare host suffix (no `www.`). Lookup is case-insensitive.
class PlatformBucket {
  static const String unknown = 'other';
  static const String none = 'none';

  /// Known recipe site → bucket label.
  ///
  /// Keys must be lowercase, no `www.`, no protocol. Match is suffix-based:
  /// `bucket.recept.ica.se` resolves to the `ica.se` entry.
  static const Map<String, String> _knownPlatforms = {
    // Swedish recipe sites
    'ica.se': 'ica',
    'koket.se': 'koket',
    'tasteline.com': 'tasteline',
    'arla.se': 'arla',
    'coop.se': 'coop',
    'mathem.se': 'mathem',
    'allakande.se': 'allakande',
    'recept.se': 'recept_se',
    'mitticity.se': 'mitticity',
    'zeinasskitchen.se': 'zeinas_kitchen',
    'mittkok.expressen.se': 'mittkok',
    // International recipe sites
    'tasty.co': 'tasty',
    'allrecipes.com': 'allrecipes',
    'bbcgoodfood.com': 'bbc_good_food',
    'foodnetwork.com': 'food_network',
    'epicurious.com': 'epicurious',
    'seriouseats.com': 'serious_eats',
    'nytimes.com': 'nyt_cooking',
    'cooking.nytimes.com': 'nyt_cooking',
    'bonappetit.com': 'bon_appetit',
    'simplyrecipes.com': 'simply_recipes',
    'kingarthurbaking.com': 'king_arthur',
    'minimalistbaker.com': 'minimalist_baker',
    'budgetbytes.com': 'budget_bytes',
    'food52.com': 'food52',
    // Social
    'instagram.com': 'instagram',
    'tiktok.com': 'tiktok',
    'youtube.com': 'youtube',
    'pinterest.com': 'pinterest',
    'pinterest.se': 'pinterest',
  };

  /// Bucket a raw hostname/domain into a low-cardinality label.
  ///
  /// Returns [none] for null/empty input (text imports without URLs),
  /// a known platform label, or [unknown] for hostnames not in the map.
  static String bucketFor(String? domainOrHost) {
    if (domainOrHost == null || domainOrHost.isEmpty) return none;

    var host = domainOrHost.toLowerCase().trim();
    if (host.startsWith('www.')) host = host.substring(4);

    final direct = _knownPlatforms[host];
    if (direct != null) return direct;

    for (final entry in _knownPlatforms.entries) {
      if (host.endsWith('.${entry.key}')) return entry.value;
    }

    return unknown;
  }
}
