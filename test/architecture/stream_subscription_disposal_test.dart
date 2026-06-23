@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BUT-1044 (BUT-1001 follow-up) — fail-loud guard against un-disposed
/// `StreamSubscription`s.
///
/// The BUT-1001 audit confirmed **zero** current production leaks — every
/// sampled `.listen()` callsite was tracked + cancelled. This guard is
/// preventative: it fails CI the moment a regression lands.
///
/// Re-scoped from the ticket's original `custom_lint` proposal to a native
/// architecture test. `custom_lint` is not installed and would add a
/// dev-dependency + analyzer-plugin process; this repo already enforces its
/// banned-pattern rules via RegExp scans in `architecture_test.dart`. A native
/// test delivers the acceptance's core value ("wired into CI so regressions
/// fail-loud") with zero new dependencies. The one thing it does not add that
/// `custom_lint` would is in-editor flagging during `dart analyze` — a clean
/// follow-up if ever wanted.
///
/// Two detectors, both calibrated to produce zero false positives on the
/// current `lib/` tree:
///   1. [findUncapturedListens] — a bare `.listen(...)` statement whose result
///      is discarded (not assigned, not returned, not a cascade).
///   2. [declaresUndisposedSubscriptionField] — a file that declares a
///      `StreamSubscription` field but never calls `.cancel(` and delegates to
///      no known disposal mixin/helper.
void main() {
  group('StreamSubscription disposal guard (BUT-1044)', () {
    // ---- Detector 1: bare `.listen()` ---------------------------------------
    group('findUncapturedListens', () {
      test('flags a discarded `.listen()` statement', () {
        const code = '''
          void wire() {
            stream.listen((event) => handle(event));
          }
        ''';
        expect(findUncapturedListens(code), isNotEmpty);
      });

      test('allows a `.listen()` captured in a field/var (= assignment)', () {
        const code = '''
          void wire() {
            _sub = stream.listen((event) => handle(event));
            final local = other.listen(handle);
          }
        ''';
        expect(findUncapturedListens(code), isEmpty);
      });

      test('allows a `.listen()` returned to the caller', () {
        const code = '''
          StreamSubscription<int> wire() {
            return stream.listen((event) => handle(event));
          }
        ''';
        expect(findUncapturedListens(code), isEmpty);
      });

      test('allows a cascade `..listen()` (object reference is retained)', () {
        const code = '''
          void wire() {
            controller..listen((event) => handle(event));
          }
        ''';
        expect(findUncapturedListens(code), isEmpty);
      });

      test('does not confuse `addListener(` with `.listen(`', () {
        const code = '''
          void wire() {
            controller.addListener(handle);
          }
        ''';
        expect(findUncapturedListens(code), isEmpty);
      });

      test('ignores matches inside comments', () {
        const code = '''
          void wire() {
            // stream.listen((e) => handle(e));  <- documented, not real
            _sub = stream.listen(handle);
          }
        ''';
        expect(findUncapturedListens(code), isEmpty);
      });
    });

    // ---- Detector 2: field declared but never cancelled ---------------------
    group('declaresUndisposedSubscriptionField', () {
      test('flags a subscription field with no `.cancel(` anywhere', () {
        const code = '''
          class Leaky {
            StreamSubscription<User?>? _authSub;
            void start() { _authSub = auth.changes.listen(_onUser); }
          }
        ''';
        expect(declaresUndisposedSubscriptionField(code), isTrue);
      });

      test('allows field + cancel in dispose', () {
        const code = '''
          class Tidy {
            StreamSubscription<User?>? _authSub;
            void start() { _authSub = auth.changes.listen(_onUser); }
            void dispose() { _authSub?.cancel(); }
          }
        ''';
        expect(declaresUndisposedSubscriptionField(code), isFalse);
      });

      test('allows delegation to a disposal mixin', () {
        const code = '''
          class Managed with StreamManagementMixin {
            StreamSubscription<int>? _sub;
            void start() { _sub = addSubscription(stream.listen(_onTick)); }
          }
        ''';
        expect(declaresUndisposedSubscriptionField(code), isFalse);
      });

      test('does not flag a Map-of-subscriptions field (bulk cancel)', () {
        const code = '''
          class Bulk {
            final Map<String, StreamSubscription> _subs = {};
            void stopAll() {
              for (final s in _subs.values) { s.cancel(); }
            }
          }
        ''';
        expect(declaresUndisposedSubscriptionField(code), isFalse);
      });

      test('does not flag a file with no subscription field at all', () {
        const code = '''
          class Plain {
            int x = 0;
          }
        ''';
        expect(declaresUndisposedSubscriptionField(code), isFalse);
      });
    });

    // ---- Allowlist (self-completing streams) --------------------------------
    group('self-completing-stream allowlist', () {
      test('a bare listen on snapshotEvents is detected but allowlisted', () {
        const code = '''
          void track() {
            uploadTask.snapshotEvents.listen((s) => report(s));
          }
        ''';
        final found = findUncapturedListens(code);
        // The detector still reports it (no special-casing in detection)…
        expect(found, contains('uploadTask.snapshotEvents'));
        // …but policy allows it: the upload task is terminal, stream closes.
        expect(found.every(_isSelfCompletingStream), isTrue);
      });

      test('the allowlist does not excuse an ordinary bare listen', () {
        expect(_isSelfCompletingStream('someStream'), isFalse);
        expect(_isSelfCompletingStream('_service.stateStream'), isFalse);
      });
    });

    // ---- Live regression guard over lib/ ------------------------------------
    test('no un-disposed StreamSubscriptions in lib/', () {
      final offenders = <String>[];

      for (final file in _libDartFiles()) {
        final source = file.readAsStringSync();
        if (!source.contains('StreamSubscription') &&
            !source.contains('.listen(')) {
          continue;
        }

        final uncaptured = findUncapturedListens(
          source,
        ).where((lhs) => !_isSelfCompletingStream(lhs)).toList();
        if (uncaptured.isNotEmpty) {
          offenders.add(
            '${file.path}: discarded .listen() on ${uncaptured.join(", ")} '
            '(capture in a field cancelled in dispose, or return it)',
          );
        }
        if (declaresUndisposedSubscriptionField(source)) {
          offenders.add(
            '${file.path}: declares a StreamSubscription field but never '
            'calls .cancel() and uses no disposal mixin/helper',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Un-disposed StreamSubscription(s) detected — leaks survive widget '
            'rebuilds / logout. Cancel in dispose()/onDispose(), delegate to '
            'StreamManagementMixin, or return the subscription to the caller.\n'
            '${offenders.join("\n")}',
      );
    });
  });
}

/// Strips `//` line comments and `/* */` block comments so the detectors never
/// fire on documented-but-inert examples. Mirrors `architecture_test.dart`.
String _stripComments(String src) => src
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp('//.*'), '');

/// Returns the left-hand expression of every bare `.listen(` call — i.e. a
/// `.listen(...)` whose result is discarded.
///
/// "Discarded" means the call is the whole statement: it directly follows a
/// statement separator (`;`, `{`, `}`) rather than an assignment (`x = …`),
/// `return`, or a wrapping call (`list.add(…)`), and is not a cascade
/// (`a..listen(…)`). Those forms retain or hand off the subscription.
///
/// Deliberately conservative to stay false-positive-free on real code:
///   - Anchors ONLY on `;{}` — never line-start — so multi-line assignments
///     (`_sub =\n    stream.listen(…)`) are not mistaken for bare statements.
///   - The captured left-hand side excludes `()`, so a `.listen()` nested in a
///     wrapping call (`_subs.add(stream.listen(…))`, captured) does not match.
///     The trade is that a leak hidden behind a method call
///     (`build().listen(…)` as a bare statement) is not caught — an accepted
///     false-negative in exchange for zero false positives.
List<String> findUncapturedListens(String source) {
  final code = _stripComments(source);
  final pattern = RegExp(r'[;{}]\s*([A-Za-z_$][\w$.\[\]]*)\.listen\s*\(');
  final findings = <String>[];
  for (final m in pattern.allMatches(code)) {
    final lhs = m.group(1)!;
    // `a..listen(` → lhs captured as `a.`; the cascade keeps `a`, so it's safe.
    if (lhs.endsWith('.')) continue;
    findings.add(lhs);
  }
  return findings;
}

/// True when [source] declares a `StreamSubscription` *field* yet contains no
/// `.cancel(` call and delegates to no known disposal mixin/helper.
///
/// Honest contract: the cancel check is **file-level** — a single `.cancel(`
/// anywhere in the file suppresses this detector for the whole file. This means
/// it CANNOT see a partial leak (two fields declared, only one cancelled) or a
/// cancel on an unrelated transient stream masking a leaked field. That is a
/// deliberate trade for zero false positives: this is a preventative
/// regression guard layered on top of the BUT-1001 manual audit (which already
/// confirmed zero current leaks), not a substitute for per-field analysis —
/// that would require the `custom_lint`/AST approach this ticket re-scoped away
/// from. It reliably catches the common case: a brand-new subscription field
/// added with no disposal at all.
bool declaresUndisposedSubscriptionField(String source) {
  final code = _stripComments(source);

  // A direct field/local declaration: `StreamSubscription<T>? _name;|=`.
  // (Generic args optional; `Map<.., StreamSubscription>` does NOT match —
  // there the type is followed by `>`, not a name.)
  final declaresField = RegExp(
    r'StreamSubscription\s*(?:<[^>]*>)?\s*\??\s+_?\w+\s*[;=]',
  ).hasMatch(code);
  if (!declaresField) return false;

  if (code.contains('.cancel(')) return false;

  // Lifecycle is owned elsewhere (a management mixin or a tracking helper).
  final delegates = RegExp(
    r'StreamManagementMixin|FirebaseSyncMixin|addSubscription\(|'
    r'trackSubscription\(|registerSubscription\(|_subscriptions\[',
  );
  if (delegates.hasMatch(code)) return false;

  return true;
}

/// Allowlist for bare `.listen()` calls on streams that terminate on their own,
/// so the subscription auto-releases when the stream closes. Currently:
///   - `*.snapshotEvents` — a Firebase Storage `UploadTask` progress stream.
///     The task is terminal (success/error closes the stream); a bare progress
///     listener is the canonical Firebase idiom, not a persistent leak.
/// Keep this list tiny and reasoned — it is the escape hatch, not the rule.
bool _isSelfCompletingStream(String listenTargetExpression) =>
    listenTargetExpression.endsWith('snapshotEvents');

Iterable<File> _libDartFiles() sync* {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}
