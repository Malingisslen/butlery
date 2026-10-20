// BUT-1907: an exception message that interpolates a raw user id reaches
// Crashlytics and the web error reporter through toString(). The
// permission exception classes mask inside their own toString(); every other
// exception built in lib/ has to mask at the throw site.
//
// The scan is anchored on a `throw` expression and reads its whole argument
// span, because a bare `userId:` or `$userId` token also appears all over
// non-exception code (logPermissionCheck, trackers, Firestore field keys).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _maskingClasses = {
  'PermissionDeniedException',
  'StaleAccessControlBaseException',
  'OfflineAccessControlChangeException',
  'ResourceNotFoundException',
  'ValidationException',
};

const _idNames =
    'userId|uid|currentUserId|resourceOwnerId|requesterId|caller|callerId|'
    'targetId|targetUserId|senderId|actorId|participantId|ownerId|friendId|'
    'memberId|otherUserId|recipientId|creatorId|authorId';

final _rawIdInterpolation = RegExp(
  '\\\$\\{?\\s*(?:[A-Za-z_]\\w*\\.)*(?:$_idNames)s?\\b(?!\\s*\\.\\s*masked)',
);

final _throwStart = RegExp(r'\bthrow\s+(?:const\s+)?([A-Z]\w*)(?:\.\w+)?\s*\(');

String _code(String source) => source
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

/// The argument text of every `throw Class(...)`, with the class name.
Iterable<(String, String)> _throwArguments(String code) sync* {
  for (final start in _throwStart.allMatches(code)) {
    var i = start.end;
    var depth = 1;
    while (i < code.length && depth > 0) {
      final c = code[i];
      if (c == "'" || c == '"') {
        i++;
        while (i < code.length && code[i] != c) {
          if (code[i] == r'\') i++;
          i++;
        }
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
      }
      i++;
    }
    yield (start.group(1)!, code.substring(start.end, i - 1));
  }
}

/// Class names of the `throw` expressions in [source] that interpolate a raw
/// identifier into their arguments.
List<String> leakingThrows(String source) => [
  for (final (cls, args) in _throwArguments(_code(source)))
    if (!_maskingClasses.contains(cls) && _rawIdInterpolation.hasMatch(args))
      cls,
];

void main() {
  group('the scan itself', () {
    test('flags a multi-line throw with an embedded semicolon', () {
      expect(
        leakingThrows(r'''
          throw StateError(
            'Conversation ${conversation.id}; member $userId is missing',
          );
        '''),
        ['StateError'],
      );
    });

    test('flags the other identifier names, also behind a receiver', () {
      for (final name in [
        r'${request.requesterId}',
        r'$resourceOwnerId',
        r'${caller}',
        r'$senderId',
      ]) {
        expect(
          leakingThrows("throw ArgumentError('x $name');"),
          ['ArgumentError'],
          reason: name,
        );
      }
    });

    test('reads a named constructor too', () {
      expect(
        leakingThrows(r"throw ArgumentError.value(x, 'uid', 'bad $uid');"),
        ['ArgumentError'],
      );
    });

    test('passes the masked spelling', () {
      expect(
        leakingThrows(r"throw ArgumentError('${userId.maskedUserId} is out');"),
        isEmpty,
      );
    });

    test('ignores the classes that mask inside toString()', () {
      expect(
        leakingThrows(r"throw PermissionDeniedException('no $userId');"),
        isEmpty,
      );
    });

    test('ignores a userId token that is not inside a throw', () {
      expect(
        leakingThrows(r'''
          logPermissionCheck(userId: userId, note: 'for $userId');
          throw StateError('no id here');
        '''),
        isEmpty,
      );
    });

    test('does not read a longer name or a comment as an identifier', () {
      expect(
        leakingThrows(r'''
          // throw StateError('x $userId');
          throw StateError('count $userIdCount');
        '''),
        isEmpty,
      );
    });
  });

  test('no exception in lib/ interpolates a raw user id', () {
    final leaks = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
      for (final cls in leakingThrows(entity.readAsStringSync())) {
        leaks.add('$path: throw $cls');
      }
    }
    expect(
      leaks,
      isEmpty,
      reason:
          'mask the id with `\${userId.maskedUserId}` (log_sanitizer.dart) '
          'or throw one of the classes that mask in toString()',
    );
  });
}
