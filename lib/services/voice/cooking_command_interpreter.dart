/// Deterministic Swedish command interpreter for Köksbutlern (cooking-mode
/// voice control — tasks/koksbutlern-plan.md, Batch B).
///
/// Pure functions, zero IO, no LLM (cost rules): a transcribed utterance in,
/// one [CookingCommand] out. Reuses the spoken-register cleanup from the
/// menu parser (fillers, Whisper punctuation) and matches against a small
/// hardcoded variant vocabulary — commands are a CLOSED set, so a lexicon
/// provider / Firestore overlay would be machinery without a payoff.
///
/// Matching rules: word-bounded with the Unicode-safe lookarounds (Dart's \b
/// treats å/ä/ö as non-word — the recorded lesson), longest variant first so
/// "nästa steg" can't be shadowed by a hypothetical shorter overlap, and
/// timer phrases are parsed before navigation so "starta en timer" is never
/// mistaken for anything else.
library;

import 'package:butlery/services/menu/parser/text_normalizer.dart'
    show stripSpokenFillers;
import 'package:butlery/utils/text/swedish_word_boundary.dart';

/// A recognized cooking-mode voice command. Sealed: the controller's switch
/// stays exhaustive when the vocabulary grows.
sealed class CookingCommand {
  const CookingCommand();
}

class NextStep extends CookingCommand {
  const NextStep();
}

class PreviousStep extends CookingCommand {
  const PreviousStep();
}

class RepeatStep extends CookingCommand {
  const RepeatStep();
}

class ReadIngredients extends CookingCommand {
  const ReadIngredients();
}

class SetTimer extends CookingCommand {
  const SetTimer(this.duration);
  final Duration duration;
}

class TimerQuery extends CookingCommand {
  const TimerQuery();
}

/// "Tyst" / "sluta" — stop any readout and close the talk-window.
class StopCommand extends CookingCommand {
  const StopCommand();
}

/// "Vad kan jag ersätta grädde med?" — the Q&A half of Köksbutlern
/// (voice-consolidation plan Phase 3). Carries the RAW ingredient span the
/// cook spoke; resolution (canonical lookup, fuzzy matching) happens in the
/// controller layer — the interpreter stays pure.
class SubstitutionQuery extends CookingCommand {
  const SubstitutionQuery(this.ingredient);
  final String ingredient;
}

/// "Hur mycket mjölk behöver jag?" — answered from the portion-scaled
/// ingredient list. Raw span, same purity rule as [SubstitutionQuery].
class QuantityQuery extends CookingCommand {
  const QuantityQuery(this.ingredient);
  final String ingredient;
}

/// "Gå till steg fyra" / "läs steg två". [step] is 1-based as spoken.
class GoToStep extends CookingCommand {
  const GoToStep(this.step);
  final int step;
}

class Unrecognized extends CookingCommand {
  const Unrecognized(this.heard);

  /// What the transcriber heard — surfaced in the UI so a mishearing is
  /// diagnosable instead of mysterious.
  final String heard;
}

// Dart \b is ASCII-only; these are the Unicode-safe Swedish word boundaries.
// Local aliases keep the interpolated duration patterns below readable; the
// definition itself is shared (BUT-1691).
const String _nb = SwedishWordBoundary.before;
const String _na = SwedishWordBoundary.after;

RegExp _phrase(String variants) => SwedishWordBoundary.boundedRegExp(variants);

// Navigation / readout vocabularies. Variants are alternations of full
// phrases; longest-first inside each alternation.
final RegExp _nextRe = _phrase('nästa steg|gå vidare|fortsätt|nästa');
final RegExp _previousRe = _phrase(
  'föregående steg|gå tillbaka|föregående|backa|tillbaka',
);
final RegExp _repeatRe = _phrase(
  'läs steget igen|läs det igen|läs igen|upprepa|vad sa du|en gång till',
);
final RegExp _ingredientsRe = _phrase(
  'läs upp ingredienserna|läs ingredienserna|vad behöver jag|ingredienserna|ingredienser',
);
final RegExp _timerQueryRe = _phrase(
  'hur lång tid kvar|hur lång tid är kvar|hur mycket tid kvar|hur går timern|tid kvar',
);
final RegExp _stopRe = _phrase('tyst|sluta läs|sluta|avbryt|stopp');

// Timer phrasing: an optional verb, the word timer/äggklocka, then a
// duration. The duration also appears bare-first in "tio minuters timer".
final RegExp _timerIntentRe = _phrase('timer|timern|äggklocka|äggklockan');

// Swedish spoken numbers for durations (1–59 covers every kitchen timer;
// tjugofem etc. are compounds of these tens + units).
const Map<String, int> _numberWords = {
  'en': 1,
  'ett': 1,
  'två': 2,
  'tre': 3,
  'fyra': 4,
  'fem': 5,
  'sex': 6,
  'sju': 7,
  'åtta': 8,
  'nio': 9,
  'tio': 10,
  'elva': 11,
  'tolv': 12,
  'tretton': 13,
  'fjorton': 14,
  'femton': 15,
  'sexton': 16,
  'sjutton': 17,
  'arton': 18,
  'nitton': 19,
  'tjugo': 20,
  'trettio': 30,
  'fyrtio': 40,
  'femtio': 50,
};

const String _numberWordAlt =
    '(?:tjugo|trettio|fyrtio|femtio)?'
    '(?:en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|tio|elva|tolv|tretton|'
    'fjorton|femton|sexton|sjutton|arton|nitton)|tjugo|trettio|fyrtio|femtio';

final RegExp _durationRe = RegExp(
  // group 1: digits (with an optional Swedish decimal comma — Whisper
  // renders spoken halves as "1,5 timme") | group 2: number word(s) |
  // group 3: unit.
  '$_nb(?:(\\d{1,3}(?:,\\d{1,2})?)|($_numberWordAlt))'
  '\\s*(minuters|minuter|minut|min|sekunders|sekunder|sekund|sek|timmars|timmar|timme)$_na',
);

// "en och en halv timme" (90 min), "två och en halv timmar", "halvannan
// timme" — base-plus-half shapes. Parsed BEFORE the idioms below, because
// 'en halv timme' is a SUBSTRING of the compound and used to shadow it
// into a 30-minute timer (review finding #5).
final RegExp _compoundHalfRe = RegExp(
  '$_nb(?:halvannan|(\\d{1,2}|$_numberWordAlt)\\s+och\\s+en\\s+halv)'
  '\\s+(timmar|timme|minuter|minut)$_na',
);

// Idiomatic durations that skip the number+unit shape entirely.
// "tre kvart" before "kvart" (ordered alternation).
final RegExp _quarterRe = _phrase('tre kvart|en kvart|kvart');
final RegExp _halfHourRe = _phrase('en halvtimme|halvtimme|en halv timme');

// Q&A frames (voice-consolidation plan Phase 3). Each frame captures ONE
// free-text ingredient span from a fixed sentence shape. Ordered most- to
// least-specific; the first match wins. All run on the normalized
// (lowercased, punctuation-stripped, filler-stripped) utterance, so `$`
// anchors are safe.
final List<RegExp> _substitutionFrames = <RegExp>[
  RegExp(r'vad kan jag ersätta (.+?) med'),
  RegExp(r'vad kan jag byta ut (.+?) mot'),
  RegExp(r'vad kan jag använda i ?stället för (.+)$'),
  RegExp(r'(?:finns det|har du) (?:någon |nån )?ersättning för (.+)$'),
  RegExp(r'ersättning för (.+)$'),
  RegExp(r'(?:jag )?har (?:ingen|inget|inga) (.+)$'),
  RegExp(r'(?:kan jag|går det att) ersätta (.+?)(?: med (?:något|nåt))?$'),
];

final List<RegExp> _quantityFrames = <RegExp>[
  RegExp(
    r'hur (?:mycket|många) (.+?) '
    r'(?:behöver jag|behövs|ska jag ha|ska det vara|ska jag använda)',
  ),
  RegExp(r'hur (?:mycket|många) (.+)$'),
];

final RegExp _goToStepRe = RegExp(
  '$_nb(?:gå till |hoppa till |läs |visa )?steg\\s+'
  '((?:\\d{1,2})|(?:$_numberWordAlt))$_na',
);

// Spoken utterances often trail context words after the ingredient
// ("jag har ingen grädde kvar", "hur mycket mjölk behöver jag nu") —
// strip the tail so the span is just the ingredient. The group REPEATS so
// stacked tails ("kvar hemma", "hemma just nu") all come off, not just the
// last one (review finding, 2026-07-14).
final RegExp _spanTailRe = RegExp(
  r'(?:\s+(?:kvar|hemma|längre|just nu|nu|då|här))+$',
);

String? _matchIngredientSpan(String normalized, List<RegExp> frames) {
  for (final frame in frames) {
    final match = frame.firstMatch(normalized);
    final span = match?.group(1)?.replaceAll(_spanTailRe, '').trim();
    if (span != null && span.isNotEmpty) return span;
  }
  return null;
}

int? _numberValue(String token) {
  final direct = _numberWords[token];
  if (direct != null) return direct;
  final digits = int.tryParse(token);
  if (digits != null) return digits;
  // Compound tens: "tjugofem" = tjugo + fem.
  for (final tens in const ['tjugo', 'trettio', 'fyrtio', 'femtio']) {
    if (token.startsWith(tens) && token.length > tens.length) {
      final unit = _numberWords[token.substring(tens.length)];
      if (unit != null && unit < 10) return _numberWords[tens]! + unit;
    }
  }
  return null;
}

int _unitSeconds(String unit) {
  if (unit.startsWith('sek')) return 1;
  if (unit.startsWith('tim')) return 3600;
  return 60;
}

/// Parses a spoken duration out of [normalized]. Returns null when none is
/// present — the caller decides whether that makes the utterance a timer
/// command without a time (unrecognized) or something else.
///
/// SUMS every duration fragment ("en timme och trettio minuter" = 90 min —
/// the exact phrasing the butler's own readouts teach, review finding #7),
/// handles base-plus-half compounds and decimal commas, and consumes each
/// matched span so no fragment is counted twice.
Duration? parseSpokenDuration(String normalized) {
  var s = normalized;
  var totalSeconds = 0;
  var found = false;

  s = s.replaceFirstMapped(_compoundHalfRe, (m) {
    final base = m.group(1) == null ? 1 : _numberValue(m.group(1)!);
    if (base == null) return m.group(0)!;
    final unit = _unitSeconds(m.group(2)!);
    totalSeconds += base * unit + unit ~/ 2;
    found = true;
    return ' ';
  });

  if (_halfHourRe.hasMatch(s)) {
    totalSeconds += 1800;
    found = true;
    s = s.replaceFirst(_halfHourRe, ' ');
  }
  final quarter = _quarterRe.firstMatch(s);
  if (quarter != null) {
    totalSeconds += quarter.group(0)!.startsWith('tre') ? 2700 : 900;
    found = true;
    s = s.replaceFirst(_quarterRe, ' ');
  }

  for (final m in _durationRe.allMatches(s)) {
    final digits = m.group(1);
    double? value;
    if (digits != null) {
      value = double.tryParse(digits.replaceFirst(',', '.'));
    } else {
      value = _numberValue(m.group(2)!)?.toDouble();
    }
    if (value == null || value <= 0) continue;
    totalSeconds += (value * _unitSeconds(m.group(3)!)).round();
    found = true;
  }

  if (!found || totalSeconds <= 0) return null;
  return Duration(seconds: totalSeconds);
}

/// Interprets a raw transcript as a cooking command.
///
/// Precedence is deliberate: stop first (a barge-in must always win), then
/// timers (their phrasing can contain navigation-ish words like "starta"),
/// then readouts, then navigation. One utterance → one command; this is a
/// command grammar, not a conversation.
CookingCommand interpretCookingCommand(String transcript) {
  final normalized = stripSpokenFillers(
    // Commas are stripped EXCEPT between digits: "1,5 timme" is Whisper's
    // rendering of a spoken half, and losing the comma turned it into a
    // FIVE-hour timer (review finding #6 — same digit-guard as the
    // ingredient assembler).
    transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[.!?]'), ' ')
        .replaceAll(RegExp(r',(?!(?<=\d,)\d)'), ' '),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();

  if (normalized.isEmpty) return Unrecognized(transcript.trim());

  if (_stopRe.hasMatch(normalized)) return const StopCommand();

  if (_timerIntentRe.hasMatch(normalized)) {
    final duration = parseSpokenDuration(normalized);
    if (duration != null) return SetTimer(duration);
    if (_timerQueryRe.hasMatch(normalized)) return const TimerQuery();
    // "sätt en timer" with no parseable time: better to admit confusion
    // than to start a timer of some invented length.
    return Unrecognized(transcript.trim());
  }
  if (_timerQueryRe.hasMatch(normalized)) return const TimerQuery();

  // Q&A before readouts/navigation: "hur mycket mjölk behöver jag" must
  // never fall through to the ingredient readout, and "läs steg två" must
  // beat the bare navigation words. Timer queries above already own
  // "hur mycket tid kvar".
  final substitutionSpan = _matchIngredientSpan(
    normalized,
    _substitutionFrames,
  );
  if (substitutionSpan != null) return SubstitutionQuery(substitutionSpan);

  // "Hur många ingredienser …" asks for the READOUT, not a quantity — fall
  // through so _ingredientsRe keeps the phrasing it always owned (review
  // finding, 2026-07-14).
  final quantitySpan = _matchIngredientSpan(normalized, _quantityFrames);
  if (quantitySpan != null && !quantitySpan.startsWith('ingrediens')) {
    return QuantityQuery(quantitySpan);
  }

  final goTo = _goToStepRe.firstMatch(normalized);
  if (goTo != null) {
    final step = _numberValue(goTo.group(1)!);
    if (step != null && step > 0) return GoToStep(step);
  }

  if (_ingredientsRe.hasMatch(normalized)) return const ReadIngredients();
  if (_repeatRe.hasMatch(normalized)) return const RepeatStep();
  if (_previousRe.hasMatch(normalized)) return const PreviousStep();
  if (_nextRe.hasMatch(normalized)) return const NextStep();

  return Unrecognized(transcript.trim());
}
