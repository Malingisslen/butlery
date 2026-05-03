/// Canonical Swedish (and common loanword) measurement units used across the
/// parsing pipeline. Single source of truth — extending this set automatically
/// covers ingredient detection in `SwedishLineClassifier` AND validation in
/// `LlmTier`. Two prior copies drifted; merge here keeps them in lockstep.
const kSwedishUnits = <String>{
  // Volume (metric)
  'dl', 'l', 'ml', 'cl', 'liter',
  // Weight (metric)
  'g', 'kg', 'hg', 'gram', 'kilo',
  // Cooking measures
  'msk', 'tsk', 'krm', 'matsked', 'tesked', 'kryddmått',
  // Packaging / countable units
  'st', 'bit', 'burk', 'pkt', 'paket', 'förp', 'påse',
  'skiva', 'klyfta', 'knippe', 'nypa', 'skvätt',
  // Pinch / dollop / drop
  'näve', 'klick', 'droppe',
  // Serving
  'port',
  // American (often appears in scraped recipes)
  'cup', 'cups', 'tbsp', 'tsp', 'oz',
};

/// Per-unit cooking-plausibility ceilings on ingredient amounts. Anything
/// above the ceiling for its unit is rejected as LLM hallucination
/// (e.g. `5000 kg salt`). Generous — chosen to admit the largest legitimate
/// batch quantity ever observed in real recipes (catering portions, bulk
/// preserving) without admitting absurd output.
///
/// Unit keys are lowercase and must appear in [kSwedishUnits]; quantities
/// for unit keys outside this map fall back to [kMaxAmountUnitless].
const kMaxAmountByUnit = <String, double>{
  'kg': 20,
  'hg': 100,
  'kilo': 20,
  'gram': 5000,
  'g': 5000,
  'l': 50,
  'liter': 50,
  'dl': 50,
  'cl': 200,
  'ml': 5000,
  'msk': 50,
  'matsked': 50,
  'tsk': 100,
  'tesked': 100,
  'krm': 100,
  'kryddmått': 100,
  'st': 500,
  'nypa': 20,
  'knippe': 20,
  'klyfta': 50,
  'skiva': 50,
  'port': 50,
  'bit': 100,
  'burk': 20,
  'paket': 20,
  'pkt': 20,
  'förp': 20,
  'påse': 20,
  'skvätt': 50,
  'näve': 20,
  'klick': 20,
  'droppe': 100,
  'cup': 50,
  'cups': 50,
  'tbsp': 50,
  'tsp': 100,
  'oz': 200,
};

/// Generic ceiling when no unit is supplied (e.g. `2 ägg`). Same as the
/// historical loose `0–10000` range — countable items have no natural
/// per-unit bound.
const kMaxAmountUnitless = 10000.0;
