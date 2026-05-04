/// BUT-525: Word lists used by `ContentFilterService` to gate UGC publishing.
///
/// Lives in its own file so the service file stays tight and the lists can
/// be replaced/expanded without churning the regex-building logic.
///
/// **Canonical form contract:** entries are stored in the same form that
/// `ContentFilterService._normalize` produces — lowercase, no diacritics,
/// no leetspeak digits. The normalizer folds variants (`F4N`, `Fan!`,
/// `B*g`, `JÄVLA`) onto the canonical entry. The regex builder additionally
/// expands each character with `+` so `fuck` catches `fuuuck`, `ffuck`,
/// and `fuckkk` without needing a length-changing run-collapse step.
///
/// **Curation principle:** false-negative-biased. We add terms only when
/// they're unambiguous slurs/harassment — `ass` and `boobs` are NOT
/// included even though they're in LDNOOBW, because they false-positive
/// on legitimate recipe vocabulary (`ass-end of the cut`, `chicken
/// breasts`). The normalizer + a curated stem set wins against a
/// brute-force LDNOOBW dump on a Swedish-first cooking app.
library;

/// Swedish profanity + targeted-harassment terms (canonical form).
///
/// Note: `bog` collides with the English word "bog" (marsh / British slang
/// for toilet paper) after diacritic strip from `bög`. Risk accepted —
/// neither sense is recipe-relevant on a Swedish-first app, and including
/// the slur outweighs the rare false-positive on English UGC.
const List<String> swedishProfanity = [
  // BUT-517 baseline — common profanity, normalized.
  'fan',
  'javla',
  'javlar',
  'helvete',
  'skit',
  'fitta',
  'kuk',
  'hora',
  'bog',
  'knulla',
  'satans',
  'forbannad',
  'horunge',
  'cp',
  'mongo',
  'blansen',
  // BUT-525 — unambiguous SV harassment / slur supplement, normalized.
  'svartskalle',
  'subba',
  'rovhal',
  'idiotjavel',
  'aphjarna',
  'dumskalle',
  'fittstim',
  'hynda',
  'fanskap',
  'javel',
  'mongoloid',
  'karring',
];

/// English profanity + targeted-harassment terms (canonical form).
///
/// LDNOOBW-derived supplement, recipe-safe subset. Excluded LDNOOBW entries
/// that false-positive on cooking vocabulary (`ass`, `boob`, `breast`,
/// `nuts`, `cock` — last collides with chicken/cooking).
const List<String> englishProfanity = [
  // BUT-517 baseline.
  'fuck',
  'fucking',
  'shit',
  'bitch',
  'asshole',
  'bastard',
  'dick',
  'pussy',
  'cunt',
  'nigger',
  'faggot',
  'retard',
  'whore',
  'slut',
  // BUT-525 — LDNOOBW-derived supplement.
  'motherfucker',
  'cocksucker',
  'twat',
  'wanker',
  'kike',
  'spic',
  'chink',
  'gook',
  'paki',
  'tranny',
  'dyke',
  'pedo',
  'pedophile',
  'rapist',
];
