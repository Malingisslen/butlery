/// Unit tests for RepositoryException.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/repository_exception.dart';

void main() {
  test('is an Exception', () {
    expect(const RepositoryException('boom'), isA<Exception>());
  });

  test('toString prefixes with class name + message', () {
    expect(const RepositoryException('boom').toString(),
        'RepositoryException: boom');
  });

  test('exposes message / code / originalError', () {
    final inner = StateError('underlying');
    final e = RepositoryException('wrapped', code: 'E42', originalError: inner);
    expect(e.message, 'wrapped');
    expect(e.code, 'E42');
    expect(e.originalError, same(inner));
  });

  test('code and originalError are optional', () {
    const e = RepositoryException('bare');
    expect(e.code, isNull);
    expect(e.originalError, isNull);
  });

  test('is a const constructor — usable in const contexts', () {
    const e = RepositoryException('const-friendly');
    expect(e.message, 'const-friendly');
  });
}
