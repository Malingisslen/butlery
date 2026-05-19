import 'dart:io';

import 'package:test/test.dart';

/// Architecture compliance tests that validate MVVM + Repository pattern.
/// Runs in CI to ensure architectural rules don't regress.
///
/// Each rule below has its own group. When a check needs to allow-list a
/// pre-existing violation, the allow-list is inline with a follow-up ticket
/// reference so the exception is auditable rather than invisible.
///
/// **Architectural rule sources:**
/// - `CLAUDE.md` — high-level pattern (MVVM + Repository).
/// - `lib/services/CLAUDE.md` — services extend `BaseService`.
/// - `lib/views/CLAUDE.md` — views never reach into repositories directly.
/// - `lib/viewmodels/CLAUDE.md` — VMs orchestrate; never import Firestore SDK.
/// - `lib/repositories/CLAUDE.md` — repositories own Firebase singleton access.
void main() {
  group('Architecture Compliance', () {
    late List<File> dartFiles;
    late Directory libDir;

    setUpAll(() {
      libDir = Directory('lib');
      if (!libDir.existsSync()) {
        fail('lib directory not found');
      }

      dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('.g.dart'))
          .where((f) => !f.path.contains('.freezed.dart'))
          .toList();
    });

    /// Returns the path of [f] relative to the repo root, normalized to
    /// forward slashes and prefixed with `lib/`. Used so allow-list lookups
    /// are unambiguous on both Windows and Unix.
    ///
    /// Why this helper exists (BUT-786 review fix): inline
    /// `'lib/${path.split('lib/').last}'` is wrong if any subdirectory is
    /// named `lib` — `.split('lib/').last` returns the segment after the
    /// LAST occurrence, silently producing the wrong relative path. Using
    /// `libDir.path` as the prefix to strip is exact and collision-free.
    String relPathOf(File f) {
      final p = f.path.replaceAll('\\', '/');
      final root = libDir.path.replaceAll('\\', '/');
      if (p.startsWith('$root/')) return 'lib/${p.substring(root.length + 1)}';
      return p;
    }

    test('lib directory contains Dart files', () {
      expect(dartFiles, isNotEmpty, reason: 'Should have Dart files in lib/');
    });

    test('MVVM directory structure exists', () {
      final requiredDirs = [
        'lib/models',
        'lib/views',
        'lib/viewmodels',
        'lib/services',
        'lib/repositories',
      ];

      for (final dir in requiredDirs) {
        expect(
          Directory(dir).existsSync(),
          isTrue,
          reason: 'Required directory $dir should exist',
        );
      }
    });

    test('core infrastructure directories exist', () {
      final coreDirs = [
        'lib/core',
        'lib/core/di',
        'lib/core/mixins',
      ];

      for (final dir in coreDirs) {
        expect(
          Directory(dir).existsSync(),
          isTrue,
          reason: 'Core directory $dir should exist',
        );
      }
    });

    test('no direct FirebaseFirestore.instance outside repositories', () {
      final violations = <String>[];

      for (final file in dartFiles) {
        final path = file.path.replaceAll('\\', '/');

        // Skip repository files - they are allowed to use Firestore directly
        if (path.contains('repository') || path.contains('_repository.dart')) {
          continue;
        }

        // Skip test entry points (e.g., main_e2e_emulator.dart)
        if (path.contains('main_e2e')) {
          continue;
        }

        // Skip the production entry point. main.dart configures Firestore
        // settings + recovers from IndexedDB corruption on web before any DI
        // module instantiates a repository — see lib/main.dart for inline
        // explanation. Documented as an "Entry Point" exception in
        // docs/architecture/ACCEPTED_LARGE_FILES.md.
        if (path.endsWith('lib/main.dart')) {
          continue;
        }

        // Skip the Firestore bootstrap helper extracted from main.dart. Its
        // whole purpose is to configure FirebaseFirestore.instance and
        // recover from IndexedDB corruption on web — touching the singleton
        // is the contract, not a violation. Tests pass an injected instance.
        if (path.endsWith('lib/core/bootstrap/firestore_bootstrap.dart')) {
          continue;
        }

        // Skip sync managers that use fallback injection pattern
        if (path.contains('sync_manager')) {
          continue;
        }

        final content = file.readAsStringSync();
        // Strip line + block comments before scanning so prose mentions
        // ("// not FirebaseFirestore.instance — see CLAUDE.md") don't
        // trigger false positives. Order matters: block comments first so
        // a `// ...` inside `/* ... */` doesn't get half-stripped.
        final stripped = content
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
            .replaceAll(RegExp(r'//.*'), '');
        if (stripped.contains('FirebaseFirestore.instance')) {
          violations.add(path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Direct FirebaseFirestore.instance usage should only be in repositories.\n'
            'Violations found in:\n${violations.join('\n')}',
      );
    });

    // BUT-777: extends the FirebaseFirestore.instance check to the four other
    // Firebase singletons (Auth, Storage, Analytics, Functions). Same allow-list
    // policy as Firestore — repositories own the singleton; everyone else must
    // go through a repository.
    //
    // Pre-existing violations are allow-listed inline below with a follow-up
    // ticket reference. New violations break the test → caught at PR time.
    test(
        'no direct Firebase{Auth,Storage,Analytics,Functions}.instance '
        'outside repositories', () {
      // Files allowed to touch the four non-Firestore singletons. Each entry
      // documents the reason. See BUT-777 follow-ups for cleanup tickets.
      const allowList = <String>{
        // DI graph — wires Firebase SDKs into repositories.
        'lib/core/di/di_container.dart',
        'lib/core/di/modules/content_module.dart',

        // FCM token-manager: structurally a service but named without
        // "_service" suffix; Firebase Messaging singleton is the contract.
        // (Tracked in BUT-782 for full DI conversion.)
        'lib/services/notifications/fcm_token_manager.dart',

        // BUT-777 follow-up cleanup queue (each gets its own ticket):
        // — services reading FirebaseAuth/Analytics/Storage directly when
        //   they should consume an AuthService / AnalyticsService /
        //   StorageRepository wrapper.
        'lib/services/account/export/compliance_export_manager.dart',
        'lib/services/llm/llm_service.dart',
        'lib/services/monitoring/web_error_reporter.dart',
        'lib/services/notifications/notification_deep_link_router.dart',
        'lib/services/notifications/notification_service.dart',
        'lib/services/parsing/feedback/parse_correction_uploader.dart',
        'lib/services/parsing/parse_event_logger.dart',
        'lib/services/performance/performance_monitoring_service.dart',

        // View-side: best-effort underage account delete. Justified inline
        // (GDPR Art 8 cleanup); documented exception, not a follow-up.
        'lib/views/onboarding/onboarding_age_gate_blocked_view.dart',
      };

      final pattern = RegExp(
        r'Firebase(Auth|Storage|Analytics|Functions)\.instance',
      );

      final violations = <String>[];

      for (final file in dartFiles) {
        final path = file.path.replaceAll('\\', '/');

        // Repositories own the singleton — same rule as Firestore check.
        // Tightened (review fix): only the repositories layer skips, not
        // anything with the substring "repository" anywhere in its path.
        if (path.contains('lib/repositories/')) continue;
        if (path.contains('main_e2e')) continue;
        if (path.endsWith('lib/main.dart')) continue;
        if (path.contains('sync_manager')) continue;

        final relPath = relPathOf(file);
        if (allowList.contains(relPath)) continue;

        final content = file.readAsStringSync();
        final stripped = content
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
            .replaceAll(RegExp(r'//.*'), '');

        if (pattern.hasMatch(stripped)) {
          violations.add(relPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Direct FirebaseAuth/Storage/Analytics/Functions.instance '
            'usage should be confined to repositories or the explicit allow-list.\n'
            'New violations:\n${violations.join('\n')}',
      );
    });

    // BUT-777: ViewModels orchestrate; they never import the Firestore SDK
    // directly. All Firestore access must go through a Repository.
    test('viewmodels do not import cloud_firestore', () {
      // Pre-existing violation — file is structurally a storage module
      // mis-located under viewmodels/. Tracked for relocation.
      const allowList = <String>{
        'lib/viewmodels/menu/menu_storage.dart',
      };

      final violations = <String>[];

      for (final file in dartFiles) {
        final path = file.path.replaceAll('\\', '/');
        if (!path.contains('lib/viewmodels/')) continue;

        final relPath = relPathOf(file);
        if (allowList.contains(relPath)) continue;

        final content = file.readAsStringSync();
        if (content.contains("import 'package:cloud_firestore/")) {
          violations.add(relPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'ViewModels must not import cloud_firestore. Use a Repository.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    // BUT-777: Views render; they never import a Firebase repository directly.
    // Views talk to ViewModels; ViewModels talk to Repositories.
    test('views do not import firebase repositories directly', () {
      // Pre-existing violation — actions helper still pulls the firebase
      // shared-content repos. Migration to a coordinator is on the follow-up
      // queue.
      const allowList = <String>{
        'lib/views/social/shared_with_me/shared_content_actions.dart',
      };

      final violations = <String>[];

      for (final file in dartFiles) {
        final path = file.path.replaceAll('\\', '/');
        if (!path.contains('lib/views/')) continue;

        final relPath = relPathOf(file);
        if (allowList.contains(relPath)) continue;

        final content = file.readAsStringSync();
        if (content
            .contains("import 'package:butlery/repositories/firebase/")) {
          violations.add(relPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Views must not import lib/repositories/firebase/ directly. '
            'Route via a ViewModel.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    // BUT-777: hardcoded `.collection('name')` string literals outside
    // repositories make refactoring collection names a multi-file hunt.
    // The repo layer pulls names from `lib/core/constants/firestore_collections.dart`;
    // services should do the same.
    test('no hardcoded .collection(\'...\') literals outside repositories', () {
      // Pre-existing violations — each gets a cleanup ticket but the rule is
      // useful immediately for new code.
      const allowList = <String>{
        // Bootstrap helper extracted from main.dart — uses a private
        // `_health` probe collection at boot. Same exception rationale as
        // the FirebaseFirestore.instance allow above.
        'lib/core/bootstrap/firestore_bootstrap.dart',
        // Doc-comment example, not actual code — false positive.
        'lib/services/account/export/export_pagination_helper.dart',
        // Follow-up: route through repositories or a Collections constant.
        'lib/services/moderation/report_service.dart',
        'lib/services/onboarding/onboarding_progress_service.dart',
        'lib/services/realtime/resource_parser_module.dart',
        'lib/services/unified/operations/modules/rating_statistics.dart',
        'lib/services/unified/unified_menu_service.dart',
      };

      // Match `.collection('name')` and `.collection("name")` literals; the
      // alternative is `.collection(Collections.something)` which we want.
      final pattern =
          RegExp(r"""\.collection\(['"][a-z_][a-zA-Z0-9_]*['"]\)""");

      final violations = <String>[];

      for (final file in dartFiles) {
        final path = file.path.replaceAll('\\', '/');

        // Repos own the literal — that's their job.
        if (path.contains('lib/repositories/')) continue;
        // Constants file *defines* collection names; allowed.
        if (path.endsWith('firestore_collections.dart')) continue;

        final relPath = relPathOf(file);
        if (allowList.contains(relPath)) continue;

        final content = file.readAsStringSync();
        final stripped = content
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
            .replaceAll(RegExp(r'//.*'), '');

        if (pattern.hasMatch(stripped)) {
          violations.add(relPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Use a constant from lib/core/constants/firestore_collections.dart '
            'instead of a string literal.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    // BUT-799: the bulk migration to `EdgeInsetsDirectional.only(start|end:)`
    // was already done in commit cc17ce235 (RTL sweep). This guard prevents
    // regression — `EdgeInsets.only(left:)` / `(right:)` is LTR-fixed and
    // breaks RTL languages (Arabic, Hebrew). The directional variant flips
    // automatically when the ambient `Directionality` is RTL.
    test(
        'no LTR-fixed EdgeInsets.only(left:|right:) in lib/ '
        '(use EdgeInsetsDirectional.only)', () {
      final pattern = RegExp(r'EdgeInsets\.only\([^)]*\b(left|right):');

      final violations = <String>[];

      for (final file in dartFiles) {
        final relPath = relPathOf(file);
        final content = file.readAsStringSync();
        final stripped = content
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
            .replaceAll(RegExp(r'//.*'), '');

        if (pattern.hasMatch(stripped)) {
          violations.add(relPath);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'EdgeInsets.only(left:|right:) breaks RTL. Use '
            'EdgeInsetsDirectional.only(start:|end:) instead.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    // BUT-836: forbid raw `data['x'] as DateTime` / `as Timestamp` casts in
    // lib/models/. They crash if the repository forwards a raw Firestore
    // Timestamp/Map shape rather than a pre-coerced DateTime. The safe path
    // is `SerializationUtils.parseRequiredDateTimeValue(data['x'])` (or
    // `safeRequiredDateTime` / `safeDateTime` for the Map variant), which
    // handles every shape we've seen in production.
    //
    // Allowed (line-level exemptions kept inline):
    //   * Nullable casts (`as DateTime?` / `as Timestamp?`) — used in
    //     copyWith sentinel patterns, never crash.
    //   * Guarded ternaries (`x is DateTime ? data['x'] as DateTime : ...`).
    //   * Casts off a non-`data[...]` source (`params[...]`, `commonFields[...]`)
    //     — those reads are pre-coerced upstream by the parsing helpers.
    test(
        'no unguarded `data[...] as DateTime|Timestamp` casts in lib/models/ '
        '(use SerializationUtils.parseRequiredDateTimeValue or safeDateTime)',
        () {
      final pattern =
          RegExp(r'''data\[[^\]]+\]\s+as\s+(?:DateTime|Timestamp)\b(?!\?)''');
      // Guard pattern: `is DateTime` / `is Timestamp` indicates a runtime
      // type check, which is the safe ternary form. The `?` of the ternary
      // can land on the same OR the next line depending on the formatter.
      final guardPattern = RegExp(r'\bis\s+(?:DateTime|Timestamp)\b');

      final violations = <String>[];

      for (final file in dartFiles) {
        final relPath = relPathOf(file);
        if (!relPath.startsWith('lib/models/')) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final raw = lines[i];
          // Strip line comments so commented-out examples don't trip us.
          final code = raw.replaceAll(RegExp(r'//.*'), '');
          if (!pattern.hasMatch(code)) continue;
          if (guardPattern.hasMatch(code)) continue;
          // Multi-line ternary: `is DateTime` may live on a previous line.
          // 2 lines back covers the common formatter break.
          final lookback =
              lines.sublist((i - 2).clamp(0, lines.length), i).join('\n');
          if (guardPattern.hasMatch(lookback)) continue;
          violations.add('$relPath:${i + 1}: ${raw.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Raw `data[...] as DateTime|Timestamp` casts crash on raw '
            'Firestore Timestamp/Map shapes. Use '
            'SerializationUtils.parseRequiredDateTimeValue(data[\'x\']) '
            'or safeDateTime/safeRequiredDateTime instead.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    // BUT-805: forbid raw `Image.network(` in `lib/` — bypasses cache and
    // re-downloads on every scroll. The canonical wrapper is
    // `CachedNetworkImage(imageUrl: ..., cacheKey:
    // FirebaseUrlUtils.stableCacheKey(url), placeholder: ..., errorWidget: ...)`.
    //
    // Allowed: `lib/` files in test fixtures (none currently), or any future
    // exemption added inline with a justification comment ending in
    // `// arch-allow: Image.network` on the SAME line.
    test('no raw `Image.network(` calls in lib/ (use CachedNetworkImage)', () {
      final pattern = RegExp(r'\bImage\.network\(');
      final allowMarker = '// arch-allow: Image.network';
      final violations = <String>[];

      for (final file in dartFiles) {
        final relPath = relPathOf(file);
        if (!relPath.startsWith('lib/')) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final raw = lines[i];
          final code = raw.replaceAll(RegExp(r'//.*'), '');
          if (!pattern.hasMatch(code)) continue;
          if (raw.contains(allowMarker)) continue;
          violations.add('$relPath:${i + 1}: ${raw.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Raw `Image.network(...)` bypasses the cache and re-downloads '
            'on every scroll. Use CachedNetworkImage with '
            'FirebaseUrlUtils.stableCacheKey(url) for cache hits.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test('widgets directory exists under lib', () {
      expect(
        Directory('lib/widgets').existsSync(),
        isTrue,
        reason: 'Widgets directory should exist for reusable UI components',
      );
    });

    test('theme directory exists for centralized styling', () {
      expect(
        Directory('lib/theme').existsSync(),
        isTrue,
        reason: 'Theme directory should exist for centralized styling',
      );
    });

    test('DI modules are properly organized', () {
      final diModulesDir = Directory('lib/core/di/modules');
      expect(
        diModulesDir.existsSync(),
        isTrue,
        reason: 'DI modules directory should exist',
      );

      final modules = diModulesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_module.dart'))
          .toList();

      expect(
        modules,
        isNotEmpty,
        reason: 'Should have at least one DI module',
      );
    });
  });

  group('File Organization', () {
    test('test directory mirrors lib structure', () {
      final testDir = Directory('test');
      expect(
        testDir.existsSync(),
        isTrue,
        reason: 'test directory should exist',
      );

      final testSubdirs = ['test/unit', 'test/widget', 'test/integration'];
      for (final dir in testSubdirs) {
        expect(
          Directory(dir).existsSync(),
          isTrue,
          reason: 'Test subdirectory $dir should exist',
        );
      }
    });
  });
}
