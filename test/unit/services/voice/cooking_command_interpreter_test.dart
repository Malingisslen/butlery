/// Golden transcript suite for the Köksbutlern command interpreter
/// (Batch B, tasks/koksbutlern-plan.md).
///
/// Intention: prove that realistic KB-Whisper renderings of spoken kitchen
/// Swedish — capitals, punctuation, fillers, digits vs number words,
/// idioms ("en kvart") — map to the right command, and that anything
/// ambiguous degrades to Unrecognized rather than a guessed action (a
/// wrong timer or a surprise step-skip is worse than asking again).
/// Pure function under test — no mocks anywhere.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/voice/cooking_command_interpreter.dart';

void main() {
  group('navigation + readout', () {
    const cases = <String, Type>{
      'Nästa.': NextStep,
      'Nästa steg, tack.': NextStep,
      'Eh, gå vidare.': NextStep,
      'Fortsätt!': NextStep,
      'Föregående.': PreviousStep,
      'Backa lite.': PreviousStep,
      'Gå tillbaka.': PreviousStep,
      'Läs steget igen.': RepeatStep,
      'Vad sa du?': RepeatStep,
      'Upprepa, tack.': RepeatStep,
      'En gång till.': RepeatStep,
      'Läs ingredienserna.': ReadIngredients,
      'Läs upp ingredienserna, tack.': ReadIngredients,
      'Vad behöver jag?': ReadIngredients,
      'Tyst.': StopCommand,
      'Sluta läs.': StopCommand,
      'Avbryt!': StopCommand,
      'Hur lång tid kvar?': TimerQuery,
      'Hur går timern?': TimerQuery,
    };
    cases.forEach((transcript, expected) {
      test('"$transcript" → $expected', () {
        expect(interpretCookingCommand(transcript).runtimeType, expected);
      });
    });
  });

  group('timers', () {
    const cases = <String, Duration>{
      'Sätt timer tio minuter.': Duration(minutes: 10),
      'Sätt en timer på 10 minuter.': Duration(minutes: 10),
      'Starta en timer på tjugofem minuter.': Duration(minutes: 25),
      'Timer fem minuter.': Duration(minutes: 5),
      'Sätt äggklockan på tre minuter.': Duration(minutes: 3),
      'Timer på en kvart.': Duration(minutes: 15),
      'Sätt en timer på en halvtimme.': Duration(minutes: 30),
      'Timer nittio sekunder — nej vänta, timer på 90 sekunder.': Duration(
        seconds: 90,
      ),
      'Sätt timer en timme.': Duration(hours: 1),
      'Timer 45 min.': Duration(minutes: 45),
      // Base-plus-half compounds (review finding #5: 'en halv timme' used
      // to shadow the full phrase into a 30-min timer):
      'Sätt en timer på en och en halv timme.': Duration(minutes: 90),
      'Timer på halvannan timme.': Duration(minutes: 90),
      'Sätt timer två och en halv minut.': Duration(seconds: 150),
      // Whisper's decimal-comma rendering (finding #6: this was FIVE hours):
      'Timer på 1,5 timme.': Duration(minutes: 90),
      // Summed compound — the butler's own readout phrasing (finding #7):
      'Sätt en timer på en timme och trettio minuter.': Duration(minutes: 90),
      'Timer fem minuter och trettio sekunder.': Duration(
        minutes: 5,
        seconds: 30,
      ),
      'Timer på tre kvart.': Duration(minutes: 45),
    };
    cases.forEach((transcript, expected) {
      test('"$transcript" → SetTimer($expected)', () {
        final cmd = interpretCookingCommand(transcript);
        expect(cmd, isA<SetTimer>(), reason: 'for "$transcript"');
        expect((cmd as SetTimer).duration, expected);
      });
    });

    test('a timer with NO parseable duration is Unrecognized, never a '
        'guessed length', () {
      final cmd = interpretCookingCommand('Sätt en timer, tack.');
      expect(cmd, isA<Unrecognized>());
    });

    test('timer precedence beats navigation-ish words in the phrase', () {
      // "starta" or "gå" fragments inside a timer utterance must not
      // trigger navigation.
      expect(
        interpretCookingCommand('Starta en timer på fem minuter och fortsätt'),
        isA<SetTimer>(),
      );
    });
  });

  group('parseSpokenDuration', () {
    test('compound tens: tjugofem / trettiofem', () {
      expect(
        parseSpokenDuration('timer tjugofem minuter'),
        const Duration(minutes: 25),
      );
      expect(
        parseSpokenDuration('trettiofem minuters timer'),
        const Duration(minutes: 35),
      );
    });

    test('å/ä/ö boundaries: "åtta minuter" parses (ASCII-\\b lesson)', () {
      expect(
        parseSpokenDuration('timer åtta minuter'),
        const Duration(minutes: 8),
      );
    });

    test('no duration → null', () {
      expect(parseSpokenDuration('sätt en timer'), isNull);
    });

    test('does not read a number out of a longer word', () {
      // "entrecôte" contains "en"; the unit requirement + boundaries must
      // keep this null rather than a 1-of-something.
      expect(parseSpokenDuration('vänd entrecôten'), isNull);
    });
  });

  group('degradation', () {
    test('unrelated kitchen talk is Unrecognized and preserves the heard '
        'text for the UI', () {
      final cmd = interpretCookingCommand('Var la jag visten någonstans?');
      expect(cmd, isA<Unrecognized>());
      expect(
        (cmd as Unrecognized).heard,
        'Var la jag visten någonstans?',
        reason: 'the UI shows what was heard — mishearings stay diagnosable',
      );
    });

    test('empty / silence-hallucination transcripts are Unrecognized', () {
      expect(interpretCookingCommand('   '), isA<Unrecognized>());
      expect(
        interpretCookingCommand('Tack för att du tittade.'),
        isA<Unrecognized>(),
      );
    });

    test('"nästan klar" must NOT trigger NextStep (word boundary)', () {
      // "nästa" inside "nästan" — the Unicode-safe boundary must hold.
      expect(
        interpretCookingCommand('Den är nästan klar.'),
        isA<Unrecognized>(),
      );
    });

    test('stop wins over everything (barge-in)', () {
      expect(
        interpretCookingCommand('Sluta läs ingredienserna.'),
        isA<StopCommand>(),
      );
    });
  });

  group('Q&A grammar (voice-consolidation plan Phase 3)', () {
    SubstitutionQuery sub(String t) =>
        interpretCookingCommand(t) as SubstitutionQuery;
    QuantityQuery qty(String t) => interpretCookingCommand(t) as QuantityQuery;
    GoToStep step(String t) => interpretCookingCommand(t) as GoToStep;

    test('substitution frames extract the ingredient span', () {
      expect(sub('Vad kan jag ersätta grädde med?').ingredient, 'grädde');
      expect(sub('Vad kan jag byta ut smöret mot?').ingredient, 'smöret');
      expect(
        sub('Vad kan jag använda i stället för bakpulver?').ingredient,
        'bakpulver',
      );
      expect(sub('Ersättning för ägg.').ingredient, 'ägg');
      expect(
        sub('Finns det någon ersättning för vetemjöl?').ingredient,
        'vetemjöl',
      );
    });

    test('"jag har ingen X kvar" frames strip the trailing context words', () {
      expect(sub('Jag har ingen grädde kvar.').ingredient, 'grädde');
      expect(sub('Har inget bakpulver hemma.').ingredient, 'bakpulver');
      expect(sub('Jag har inga champinjoner.').ingredient, 'champinjoner');
      // STACKED tails must all come off, not just the last one.
      expect(sub('Jag har ingen grädde kvar hemma.').ingredient, 'grädde');
      expect(sub('Har inget smör hemma just nu.').ingredient, 'smör');
    });

    test('"hur många ingredienser" stays a READOUT, never a quantity miss', () {
      expect(
        interpretCookingCommand('Hur många ingredienser behöver jag?'),
        isA<ReadIngredients>(),
      );
      expect(
        interpretCookingCommand('Hur mycket ingredienser är det?'),
        isA<ReadIngredients>(),
      );
    });

    test('multi-word and non-a-zåäö ingredients survive the span capture', () {
      expect(
        sub('Vad kan jag ersätta crème fraiche med?').ingredient,
        'crème fraiche',
      );
      expect(
        sub('Jag har ingen färsk koriander kvar.').ingredient,
        'färsk koriander',
      );
    });

    test('fillers are stripped before the frame match', () {
      expect(
        sub('Öh, vad kan jag typ ersätta grädde med då?').ingredient,
        'grädde',
      );
    });

    test('quantity frames extract the ingredient span', () {
      expect(qty('Hur mycket mjölk behöver jag?').ingredient, 'mjölk');
      expect(qty('Hur många ägg ska jag ha?').ingredient, 'ägg');
      expect(qty('Hur mycket socker?').ingredient, 'socker');
      expect(qty('Hur mycket smör ska jag använda nu?').ingredient, 'smör');
    });

    test('go-to-step parses word and digit numbers', () {
      expect(step('Gå till steg fyra.').step, 4);
      expect(step('Läs steg två.').step, 2);
      expect(step('Steg 7.').step, 7);
      expect(step('Hoppa till steg tolv.').step, 12);
    });

    test('Q&A precedence never steals the existing commands', () {
      // Timer query owns "hur mycket tid kvar".
      expect(
        interpretCookingCommand('Hur mycket tid kvar?'),
        isA<TimerQuery>(),
      );
      // Bare navigation stays navigation ("steg" without a number).
      expect(interpretCookingCommand('Nästa steg.'), isA<NextStep>());
      // The ingredient READOUT keeps its phrasing.
      expect(
        interpretCookingCommand('Vad behöver jag?'),
        isA<ReadIngredients>(),
      );
      // "läs steget igen" is a repeat, not a go-to.
      expect(
        interpretCookingCommand('Läs steget igen.'),
        isA<RepeatStep>(),
      );
    });

    test('a substitution ask with no extractable span stays honest', () {
      expect(
        interpretCookingCommand('Kan jag ersätta?'),
        isA<Unrecognized>(),
      );
    });
  });
}
