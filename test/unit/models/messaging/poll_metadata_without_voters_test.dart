import 'package:butlery/models/messaging/poll.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _meta() => {
  'poll': {
    'question': 'Middag?',
    'options': [
      {
        'id': 'a',
        'voterIds': ['u1', 'u2'],
      },
      {
        'id': 'b',
        'voterIds': ['u3'],
      },
    ],
  },
  'other': 1,
};

void main() {
  group('metadataWithoutVoters', () {
    test('removes blocked voters and keeps every other key', () {
      final out = metadataWithoutVoters(_meta(), {'u2', 'u3'})!;
      final options = (out['poll'] as Map)['options'] as List;
      expect((options[0] as Map)['voterIds'], ['u1']);
      expect((options[1] as Map)['voterIds'], <String>[]);
      expect((out['poll'] as Map)['question'], 'Middag?');
      expect(out['other'], 1);
    });

    test('returns the same instance when nobody is removed', () {
      final meta = _meta();
      expect(identical(metadataWithoutVoters(meta, {'zz'}), meta), isTrue);
      expect(identical(metadataWithoutVoters(meta, {}), meta), isTrue);
    });

    test('does not mutate its input', () {
      final meta = _meta();
      metadataWithoutVoters(meta, {'u1'});
      final options = (meta['poll'] as Map)['options'] as List;
      expect((options[0] as Map)['voterIds'], ['u1', 'u2']);
    });

    test('fails open on unreadable shapes', () {
      for (final meta in <Map<String, dynamic>?>[
        null,
        {},
        {'poll': 'x'},
        {
          'poll': {'options': 'x'},
        },
        {
          'poll': {
            'options': [
              'x',
              {'voterIds': 'x'},
            ],
          },
        },
      ]) {
        expect(identical(metadataWithoutVoters(meta, {'u1'}), meta), isTrue);
      }
    });
  });
}
