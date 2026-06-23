import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';

void main() {
  group('PersonalTagGroup', () {
    group('creation', () {
      test('creates group with required fields', () {
        final now = DateTime.now();
        final group = PersonalTagGroup(
          id: 'group-1',
          name: 'Test Group',
          createdAt: now,
          updatedAt: now,
        );

        expect(group.id, 'group-1');
        expect(group.name, 'Test Group');
        expect(group.sortOrder, 0);
        expect(group.isExclusive, isFalse);
      });

      test('creates group with all fields', () {
        final now = DateTime.now();
        final group = PersonalTagGroup(
          id: 'group-1',
          name: 'Meal Planning',
          sortOrder: 5,
          isExclusive: true,
          createdAt: now,
          updatedAt: now,
        );

        expect(group.sortOrder, 5);
        expect(group.isExclusive, isTrue);
      });

      test('factory create generates ID and timestamps', () {
        final group = PersonalTagGroup.create(
          name: 'New Group',
          isExclusive: true,
        );

        expect(group.id, isNotEmpty);
        expect(group.name, 'New Group');
        expect(group.isExclusive, isTrue);
        expect(group.createdAt, isNotNull);
        expect(group.updatedAt, isNotNull);
      });

      test('factory create trims name', () {
        final group = PersonalTagGroup.create(name: '  Test Group  ');
        expect(group.name, 'Test Group');
      });
    });

    group('isExclusive', () {
      test('defaults to false', () {
        final group = PersonalTagGroup.create(name: 'Test');
        expect(group.isExclusive, isFalse);
      });

      test('can be set to true', () {
        final group = PersonalTagGroup.create(name: 'Test', isExclusive: true);
        expect(group.isExclusive, isTrue);
      });
    });

    group('serialization', () {
      test('toFirestore includes all fields', () {
        final group = PersonalTagGroup.create(
          name: 'Test',
          sortOrder: 3,
          isExclusive: true,
        );
        final map = group.toFirestore();

        expect(map.containsKey('name'), isTrue);
        expect(map.containsKey('sortOrder'), isTrue);
        expect(map.containsKey('isExclusive'), isTrue);
        expect(map['isExclusive'], isTrue);
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });

      test('toJson includes id', () {
        final group = PersonalTagGroup(
          id: 'group-123',
          name: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final json = group.toJson();

        expect(json['id'], 'group-123');
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());
      });

      test('fromMap parses all fields', () {
        final group = PersonalTagGroup.fromMap('group-1', {
          'name': 'Meal Planning',
          'sortOrder': 3,
          'isExclusive': true,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        expect(group.id, 'group-1');
        expect(group.name, 'Meal Planning');
        expect(group.sortOrder, 3);
        expect(group.isExclusive, isTrue);
      });

      test('fromMap handles missing optional fields', () {
        final group = PersonalTagGroup.fromMap('group-1', {
          'name': 'Test',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        expect(group.sortOrder, 0);
        expect(group.isExclusive, isFalse);
      });

      test('fromJson parses ISO dates', () {
        final now = DateTime.now();
        final group = PersonalTagGroup.fromJson({
          'id': 'group-1',
          'name': 'Test',
          'sortOrder': 2,
          'isExclusive': true,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });

        expect(group.id, 'group-1');
        expect(group.name, 'Test');
        expect(group.isExclusive, isTrue);
      });

      test('fromJson throws on missing id', () {
        expect(
          () => PersonalTagGroup.fromJson({
            'name': 'Test',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('roundtrip toJson/fromJson preserves all data', () {
        final original = PersonalTagGroup(
          id: 'group-1',
          name: 'Meal Planning',
          sortOrder: 5,
          isExclusive: true,
          createdAt: DateTime(2024, 1, 15, 10, 30),
          updatedAt: DateTime(2024, 1, 16, 14, 45),
        );

        final json = original.toJson();
        final restored = PersonalTagGroup.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.sortOrder, original.sortOrder);
        expect(restored.isExclusive, original.isExclusive);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = PersonalTagGroup.create(
          name: 'Original',
          isExclusive: false,
        );

        final updated = original.copyWith(
          name: 'Updated',
          sortOrder: 10,
          isExclusive: true,
        );

        expect(updated.id, original.id);
        expect(updated.name, 'Updated');
        expect(updated.sortOrder, 10);
        expect(updated.isExclusive, isTrue);
      });

      test('updates updatedAt automatically', () {
        final original = PersonalTagGroup(
          id: 'test',
          name: 'Test',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final beforeUpdate = DateTime.now();
        final updated = original.copyWith(name: 'Updated');

        expect(
          updated.updatedAt.isAfter(beforeUpdate) ||
              updated.updatedAt.isAtSameMomentAs(beforeUpdate),
          isTrue,
        );
      });
    });

    group('validation', () {
      test('validates empty name', () {
        expect(PersonalTagGroup.validateName(''), isNotNull);
        expect(PersonalTagGroup.validateName('  '), isNotNull);
        expect(PersonalTagGroup.validateName(null), isNotNull);
      });

      test('validates name too long', () {
        final longName = 'a' * 51;
        expect(PersonalTagGroup.validateName(longName), isNotNull);
      });

      test('validates valid name', () {
        expect(PersonalTagGroup.validateName('Valid Group'), isNull);
        expect(PersonalTagGroup.validateName('a' * 50), isNull);
      });

      test('isValid reflects validation state', () {
        final validGroup = PersonalTagGroup.create(name: 'Valid');
        expect(validGroup.isValid, isTrue);

        final invalidGroup = PersonalTagGroup(
          id: 'test',
          name: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        expect(invalidGroup.isValid, isFalse);
      });

      group('boundary cases', () {
        test('should pass when name is exactly 50 characters', () {
          final name50 = 'a' * 50;
          expect(name50.length, 50);
          expect(PersonalTagGroup.validateName(name50), isNull);
        });

        test('should fail when name is 51 characters', () {
          final name51 = 'a' * 51;
          expect(name51.length, 51);
          expect(PersonalTagGroup.validateName(name51), isNotNull);
        });

        test('should fail when name is null', () {
          expect(PersonalTagGroup.validateName(null), isNotNull);
        });

        test('should fail when name is empty string', () {
          expect(PersonalTagGroup.validateName(''), isNotNull);
        });

        test('should fail when name is only whitespace', () {
          expect(PersonalTagGroup.validateName('   '), isNotNull);
        });

        test('should pass when name is a single character', () {
          // PersonalTagGroup.validateName has no minimum length beyond non-empty
          expect(PersonalTagGroup.validateName('a'), isNull);
        });

        test('should pass when name contains a comma', () {
          // Groups have no comma restriction (unlike PersonalTag)
          expect(PersonalTagGroup.validateName('Group, Other'), isNull);
        });

        test('should pass when name is a reserved system tag name', () {
          // Groups have no reserved name check (unlike PersonalTag)
          expect(PersonalTagGroup.validateName('sommar'), isNull);
        });

        test('should pass when name is a reserved dietary name', () {
          // Groups have no reserved name check (unlike PersonalTag)
          expect(PersonalTagGroup.validateName('vegetarisk'), isNull);
        });

        test('should pass when name is a valid unique name', () {
          expect(PersonalTagGroup.validateName('Svårighetsgrad'), isNull);
          expect(PersonalTagGroup.validateName('Meal Planning'), isNull);
        });

        test(
          'should pass when name has leading/trailing whitespace that trims valid',
          () {
            expect(PersonalTagGroup.validateName('  Valid Group  '), isNull);
          },
        );

        test('should evaluate length after trimming', () {
          final name49 = 'a' * 49;
          expect(PersonalTagGroup.validateName('  $name49  '), isNull);
        });

        test('should fail when trimmed content exceeds 50 characters', () {
          final name51 = 'a' * 51;
          expect(PersonalTagGroup.validateName('  $name51  '), isNotNull);
        });
      });
    });

    group('equality', () {
      test('groups with same ID are equal', () {
        final group1 = PersonalTagGroup(
          id: 'same-id',
          name: 'Name 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final group2 = PersonalTagGroup(
          id: 'same-id',
          name: 'Name 2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(group1, equals(group2));
        expect(group1.hashCode, equals(group2.hashCode));
      });

      test('groups with different ID are not equal', () {
        final group1 = PersonalTagGroup(
          id: 'id-1',
          name: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final group2 = PersonalTagGroup(
          id: 'id-2',
          name: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(group1, isNot(equals(group2)));
      });
    });

    group('toString', () {
      test('returns readable string', () {
        final group = PersonalTagGroup(
          id: 'group-123',
          name: 'Meal Planning',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(group.toString(), contains('group-123'));
        expect(group.toString(), contains('Meal Planning'));
      });
    });
  });
}
