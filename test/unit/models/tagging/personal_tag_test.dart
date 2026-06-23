import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';

import '../../../infrastructure/builders/personal_tag_builder.dart';

void main() {
  group('PersonalTag', () {
    group('creation', () {
      test('creates tag with required fields', () {
        final now = DateTime.now();
        final tag = PersonalTag(
          id: 'tag-1',
          name: 'Test Tag',
          createdAt: now,
          updatedAt: now,
        );

        expect(tag.id, 'tag-1');
        expect(tag.name, 'Test Tag');
        expect(tag.sortOrder, 0);
        expect(tag.groupId, isNull);
        expect(tag.rules, isEmpty);
      });

      test('creates tag with all fields', () {
        final now = DateTime.now();
        final rule = PersonalTagRuleBuilder()
            .withName('Test Rule')
            .withIngredientCondition('kyckling')
            .build();

        final tag = PersonalTag(
          id: 'tag-1',
          name: 'Test Tag',
          createdAt: now,
          updatedAt: now,
          sortOrder: 5,
          groupId: 'group-1',
          rules: [rule],
        );

        expect(tag.groupId, 'group-1');
        expect(tag.rules, hasLength(1));
        expect(tag.rules.first.name, 'Test Rule');
      });

      test('factory create generates ID and timestamps', () {
        final tag = PersonalTag.create(
          name: 'New Tag',
          groupId: 'group-1',
        );

        expect(tag.id, isNotEmpty);
        expect(tag.name, 'New Tag');
        expect(tag.groupId, 'group-1');
        expect(tag.createdAt, isNotNull);
        expect(tag.updatedAt, isNotNull);
      });

      test('factory create trims name', () {
        final tag = PersonalTag.create(name: '  Test Tag  ');
        expect(tag.name, 'Test Tag');
      });
    });

    group('groupId', () {
      test('supports null groupId for ungrouped tags', () {
        final tag = PersonalTagBuilder().build();
        expect(tag.groupId, isNull);
      });

      test('supports non-null groupId for grouped tags', () {
        final tag = PersonalTagBuilder().withGroupId('group-123').build();
        expect(tag.groupId, 'group-123');
      });
    });

    group('embedded rules', () {
      test('supports empty rules list', () {
        final tag = PersonalTagBuilder().build();
        expect(tag.rules, isEmpty);
      });

      test('supports single rule', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Fish Rule')
            .withPropertyCondition('seafood')
            .build();

        final tag = PersonalTagBuilder().withRules([rule]).build();

        expect(tag.rules, hasLength(1));
        expect(tag.rules.first.name, 'Fish Rule');
      });

      test('supports multiple rules', () {
        final rule1 = PersonalTagRuleBuilder()
            .withName('Fish Rule')
            .withPropertyCondition('seafood')
            .build();
        final rule2 = PersonalTagRuleBuilder()
            .withName('Quick Rule')
            .withConditions([
              const RuleCondition(
                type: ConditionType.time,
                operator: ConditionOperator.lessThan,
                value: 30,
              ),
            ])
            .build();

        final tag = PersonalTagBuilder().withRules([rule1, rule2]).build();

        expect(tag.rules, hasLength(2));
      });
    });

    group('serialization', () {
      test('toFirestore excludes null optional fields', () {
        final tag = PersonalTagBuilder().withName('Test').build();

        final map = tag.toFirestore();

        expect(map.containsKey('name'), isTrue);
        expect(map.containsKey('groupId'), isFalse);
        expect(map.containsKey('rules'), isFalse);
      });

      test('toFirestore includes groupId when set', () {
        final tag = PersonalTagBuilder().withGroupId('group-1').build();
        final map = tag.toFirestore();

        expect(map['groupId'], 'group-1');
      });

      test('toFirestore includes embedded rules', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Test Rule')
            .withIngredientCondition('kyckling')
            .build();

        final tag = PersonalTagBuilder().withRules([rule]).build();
        final map = tag.toFirestore();

        expect(map.containsKey('rules'), isTrue);
        expect(map['rules'], isA<List>());
        expect((map['rules'] as List), hasLength(1));
      });

      test('toJson includes id and groupId', () {
        final tag = PersonalTagBuilder()
            .withId('tag-123')
            .withGroupId('group-1')
            .build();

        final json = tag.toJson();

        expect(json['id'], 'tag-123');
        expect(json['groupId'], 'group-1');
      });

      test('fromMap parses groupId', () {
        final tag = PersonalTag.fromMap('tag-1', {
          'name': 'Test',
          'groupId': 'group-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        expect(tag.groupId, 'group-123');
      });

      test('fromMap parses embedded rules', () {
        final now = Timestamp.now();
        final tag = PersonalTag.fromMap('tag-1', {
          'name': 'Test',
          'createdAt': now,
          'updatedAt': now,
          'rules': [
            {
              'id': 'rule-1',
              'name': 'Test Rule',
              'conditions': const [
                {
                  'type': 'ingredient',
                  'operator': 'contains',
                  'value': 'kyckling',
                },
              ],
              'matchMode': 'ALL',
              'isEnabled': true,
              'createdAt': now,
              'updatedAt': now,
            },
          ],
        });

        expect(tag.rules, hasLength(1));
        expect(tag.rules.first.name, 'Test Rule');
        expect(tag.rules.first.conditions, hasLength(1));
      });

      test('fromMap handles missing rules gracefully', () {
        final tag = PersonalTag.fromMap('tag-1', {
          'name': 'Test',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        expect(tag.rules, isEmpty);
      });

      test('fromMap handles invalid rules gracefully', () {
        final tag = PersonalTag.fromMap('tag-1', {
          'name': 'Test',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'rules': 'invalid', // Not a list
        });

        expect(tag.rules, isEmpty);
      });

      test('fromJson parses groupId and rules', () {
        final tag = PersonalTag.fromJson({
          'id': 'tag-1',
          'name': 'Test',
          'groupId': 'group-1',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'rules': [
            {
              'id': 'rule-1',
              'name': 'Test Rule',
              'conditions': const [
                {
                  'type': 'keyword',
                  'operator': 'contains',
                  'value': 'pasta',
                },
              ],
              'matchMode': 'ANY',
              'isEnabled': true,
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            },
          ],
        });

        expect(tag.groupId, 'group-1');
        expect(tag.rules, hasLength(1));
      });

      test('roundtrip toJson/fromJson preserves all data', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Fish Rule')
            .withPropertyCondition('seafood')
            .build();

        final original = PersonalTagBuilder()
            .withId('tag-1')
            .withName('Test Tag')
            .withGroupId('group-1')
            .withRules([rule])
            .build();

        final json = original.toJson();
        final restored = PersonalTag.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.groupId, original.groupId);
        expect(restored.rules, hasLength(1));
        expect(restored.rules.first.name, rule.name);
      });
    });

    group('copyWith', () {
      test('creates copy with updated groupId', () {
        final original = PersonalTagBuilder().build();
        final updated = original.copyWith(groupId: 'group-new');

        expect(updated.groupId, 'group-new');
        expect(updated.id, original.id);
      });

      test('clearGroupId removes groupId', () {
        final original = PersonalTagBuilder().withGroupId('group-1').build();
        final updated = original.copyWith(clearGroupId: true);

        expect(updated.groupId, isNull);
      });

      test('updates rules list', () {
        final original = PersonalTagBuilder().build();
        final newRule = PersonalTagRuleBuilder()
            .withName('New Rule')
            .withKeywordCondition('test')
            .build();

        final updated = original.copyWith(rules: [newRule]);

        expect(updated.rules, hasLength(1));
        expect(updated.rules.first.name, 'New Rule');
      });

      test('updates updatedAt automatically', () {
        final original = PersonalTagBuilder().build();
        final beforeUpdate = DateTime.now();

        // Small delay to ensure timestamp difference
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
        expect(PersonalTag.validateName(''), isNotNull);
        expect(PersonalTag.validateName('  '), isNotNull);
      });

      test('validates name too long', () {
        final longName = 'a' * 51;
        expect(PersonalTag.validateName(longName), isNotNull);
      });

      test('validates name with comma', () {
        expect(PersonalTag.validateName('Tag, with comma'), isNotNull);
      });

      test('validates valid name', () {
        expect(PersonalTag.validateName('Valid Tag'), isNull);
        expect(PersonalTag.validateName('a' * 50), isNull);
      });

      test('isValid reflects validation state', () {
        final validTag = PersonalTagBuilder().withName('Valid').build();
        expect(validTag.isValid, isTrue);

        // Create invalid tag directly (bypass factory validation)
        final invalidTag = PersonalTag(
          id: 'test',
          name: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        expect(invalidTag.isValid, isFalse);
      });

      group('boundary cases', () {
        test('should pass when name is exactly 50 characters', () {
          final name50 = 'a' * 50;
          expect(name50.length, 50);
          expect(PersonalTag.validateName(name50), isNull);
        });

        test('should fail when name is 51 characters', () {
          final name51 = 'a' * 51;
          expect(name51.length, 51);
          expect(PersonalTag.validateName(name51), isNotNull);
        });

        test('should fail when name is null', () {
          expect(PersonalTag.validateName(null), isNotNull);
        });

        test('should fail when name is empty string', () {
          expect(PersonalTag.validateName(''), isNotNull);
        });

        test('should fail when name is only whitespace', () {
          expect(PersonalTag.validateName('   '), isNotNull);
        });

        test('should pass when name is a single character', () {
          // PersonalTag.validateName has no minimum length beyond non-empty
          expect(PersonalTag.validateName('a'), isNull);
        });

        test('should fail when name contains a comma', () {
          expect(PersonalTag.validateName('Tag, Other'), isNotNull);
        });

        test('should fail when name is reserved season tag "sommar"', () {
          expect(PersonalTag.validateName('sommar'), isNotNull);
        });

        test(
          'should fail when name is reserved season tag case-insensitive',
          () {
            expect(PersonalTag.validateName('Sommar'), isNotNull);
            expect(PersonalTag.validateName('SOMMAR'), isNotNull);
          },
        );

        test('should fail when name is reserved dietary tag "vegetarisk"', () {
          expect(PersonalTag.validateName('vegetarisk'), isNotNull);
        });

        test('should fail when name is reserved allergen tag', () {
          expect(PersonalTag.validateName('glutenfri'), isNotNull);
          expect(PersonalTag.validateName('laktosfri'), isNotNull);
        });

        test('should fail when name is reserved cooking method tag', () {
          expect(PersonalTag.validateName('ugnsbakad'), isNotNull);
          expect(PersonalTag.validateName('grillad'), isNotNull);
        });

        test('should fail when name is reserved cuisine tag', () {
          expect(PersonalTag.validateName('italiensk'), isNotNull);
          expect(PersonalTag.validateName('thailändsk'), isNotNull);
        });

        test('should pass when name is a valid unique name', () {
          expect(PersonalTag.validateName('Mammas Recept'), isNull);
          expect(PersonalTag.validateName('Fredagsmiddag Special'), isNull);
        });

        test(
          'should pass when name has leading/trailing whitespace that trims valid',
          () {
            // Whitespace is trimmed before length check, so padded 50-char name passes
            expect(PersonalTag.validateName('  Valid Tag  '), isNull);
          },
        );

        test('should evaluate length after trimming', () {
          // 49 chars + surrounding spaces = still valid after trim
          final name49 = 'a' * 49;
          expect(PersonalTag.validateName('  $name49  '), isNull);
        });

        test('should fail when trimmed content exceeds 50 characters', () {
          final name51 = 'a' * 51;
          expect(PersonalTag.validateName('  $name51  '), isNotNull);
        });
      });
    });

    group('equality', () {
      test('tags with same ID are equal', () {
        final tag1 = PersonalTagBuilder()
            .withId('same-id')
            .withName('Name 1')
            .build();
        final tag2 = PersonalTagBuilder()
            .withId('same-id')
            .withName('Name 2')
            .build();

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('tags with different ID are not equal', () {
        final tag1 = PersonalTagBuilder().withId('id-1').build();
        final tag2 = PersonalTagBuilder().withId('id-2').build();

        expect(tag1, isNot(equals(tag2)));
      });
    });
  });
}
