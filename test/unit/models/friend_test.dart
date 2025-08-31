// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/friend.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('Friend', () {
    group('Friend Model', () {
      test('should create friend with all required fields', () {
        final friend = Friend(
          id: 'friend_123',
          name: 'Anna Andersson',
          email: 'anna@example.com',
        );

        expect(friend.id, equals('friend_123'));
        expect(friend.name, equals('Anna Andersson'));
        expect(friend.email, equals('anna@example.com'));
      });

      test('should handle Swedish characters in name', () {
        final friend = Friend(
          id: 'friend_456',
          name: 'Åsa Öberg',
          email: 'asa.oberg@example.se',
        );

        expect(friend.name, equals('Åsa Öberg'));
      });

      test('should handle various email formats', () {
        final testCases = [
          'simple@example.com',
          'user.name@example.com',
          'user+tag@example.com',
          'user@subdomain.example.com',
          'user@example.co.uk',
          'user123@example.se',
        ];

        for (final email in testCases) {
          final friend = Friend(
            id: 'test_id',
            name: 'Test User',
            email: email,
          );
          expect(friend.email, equals(email));
        }
      });

      test('should handle empty strings for fields', () {
        final friend = Friend(
          id: '',
          name: '',
          email: '',
        );

        expect(friend.id, equals(''));
        expect(friend.name, equals(''));
        expect(friend.email, equals(''));
      });

      test('should handle special characters in name', () {
        final friend = Friend(
          id: 'friend_789',
          name: "O'Brien-Smith",
          email: 'obrien@example.com',
        );

        expect(friend.name, equals("O'Brien-Smith"));
      });

      test('should create multiple unique instances', () {
        final friend1 = Friend(
          id: 'friend_1',
          name: 'Friend One',
          email: 'one@example.com',
        );

        final friend2 = Friend(
          id: 'friend_2',
          name: 'Friend Two',
          email: 'two@example.com',
        );

        expect(friend1.id, isNot(equals(friend2.id)));
        expect(friend1.name, isNot(equals(friend2.name)));
        expect(friend1.email, isNot(equals(friend2.email)));
      });

      test('should handle long names', () {
        final longName = 'Johannes Chrysostomus Wolfgangus Theophilus Mozart';
        final friend = Friend(
          id: 'friend_long',
          name: longName,
          email: 'mozart@example.com',
        );

        expect(friend.name, equals(longName));
      });

      test('should be suitable for use in collections', () {
        final friends = [
          Friend(id: '1', name: 'Alice', email: 'alice@example.com'),
          Friend(id: '2', name: 'Bob', email: 'bob@example.com'),
          Friend(id: '3', name: 'Charlie', email: 'charlie@example.com'),
        ];

        expect(friends.length, equals(3));
        expect(friends[0].name, equals('Alice'));
        expect(friends[1].name, equals('Bob'));
        expect(friends[2].name, equals('Charlie'));

        // Can be filtered
        final filtered = friends.where((f) => f.name.startsWith('A')).toList();
        expect(filtered.length, equals(1));
        expect(filtered.first.name, equals('Alice'));

        // Can be mapped
        final names = friends.map((f) => f.name).toList();
        expect(names, equals(['Alice', 'Bob', 'Charlie']));
      });

      test('should handle typical Swedish names', () {
        final swedishFriends = [
          Friend(id: '1', name: 'Erik Eriksson', email: 'erik@example.se'),
          Friend(id: '2', name: 'Lars Larsson', email: 'lars@example.se'),
          Friend(id: '3', name: 'Astrid Lindgren', email: 'astrid@example.se'),
          Friend(id: '4', name: 'Björn Borg', email: 'bjorn@example.se'),
        ];

        for (final friend in swedishFriends) {
          expect(friend.name, isNotEmpty);
          expect(friend.email, contains('@example.se'));
        }
      });

      test('should be usable as a value object', () {
        final friend = Friend(
          id: 'immutable_123',
          name: 'Immutable Friend',
          email: 'immutable@example.com',
        );

        // Fields are final and cannot be changed
        expect(friend.id, equals('immutable_123'));
        expect(friend.name, equals('Immutable Friend'));
        expect(friend.email, equals('immutable@example.com'));

        // Would need to create a new instance to "change" values
        final updatedFriend = Friend(
          id: friend.id,
          name: 'Updated Name',
          email: friend.email,
        );

        expect(updatedFriend.id, equals(friend.id));
        expect(updatedFriend.name, isNot(equals(friend.name)));
        expect(updatedFriend.email, equals(friend.email));
      });
    });
  });
}