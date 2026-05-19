// BUT-810: measure adoption of cross-cutting base classes / mixins under lib/
// and emit a Markdown report to docs/architecture/adoption-status.md.
//
// Inline adoption percentages in prompt + analysis docs have drifted into
// internal contradiction (e.g. "BFR ~45%" vs "BFR ~78%" in the same file).
// This tool produces a single machine-derived source so future audits cite
// `adoption-status.md` instead of inlining stale numbers.
//
// Run: `dart run tools/measure_adoption.dart`
//
// CI nightly job (post-BUT-776) re-runs the tool and commits the file if
// changed. The same job invokes BUT-776's lint that forbids inline % in
// orchestrator/prompt files.

import 'dart:io';

void main(List<String> args) async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ not found — run from repo root.');
    exit(2);
  }

  final dartFiles = libDir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
          (f) => !f.path.replaceAll('\\', '/').contains('lib/site-packages/'))
      .toList(growable: false);

  // Denominators count canonical artifact files only (filename suffix
  // determines candidacy), not every class declaration. Otherwise private
  // helper classes / models inside a service file inflate the denominator
  // and undercount adoption — e.g. `lib/services/CLAUDE.md` claims ~98%
  // BaseService adoption against a 83-file pool, which only matches the
  // filename-based count.
  bool isServiceFile(File f) =>
      f.path.endsWith('_service.dart') && _isUnder(f, 'lib/services/');
  bool isRepoFile(File f) =>
      f.path.endsWith('_repository.dart') &&
      _isUnder(f, 'lib/repositories/firebase/');
  bool isViewModelFile(File f) =>
      f.path.endsWith('_viewmodel.dart') && _isUnder(f, 'lib/viewmodels/');

  final services = dartFiles.where(isServiceFile).toList(growable: false);
  final repos = dartFiles.where(isRepoFile).toList(growable: false);
  final viewmodels = dartFiles.where(isViewModelFile).toList(growable: false);

  // Read every file once into memory; the regexes run against the cache
  // (5x I/O reduction at ~1300 files).
  final cache = <String, String>{
    for (final f in dartFiles) f.path: _read(f),
  };

  final baseService =
      _countMatching(cache, services, RegExp(r'\bextends BaseService\b'));
  final errorHandlingMixin = _countMatching(
      cache, services, RegExp(r'\bwith[^;{]*\bErrorHandlingMixin\b'));
  final baseFirebaseRepo = _countMatching(
      cache, repos, RegExp(r'\bextends BaseFirebaseRepository<'));
  // BUT-873: PermissionValidationMixin is mixed into BaseFirebaseRepository
  // (lib/repositories/firebase/base_firebase_repository.dart:17), so most
  // adopters get it transitively without naming it. Effective coverage =
  // files that either declare the mixin directly OR extend BFR. Reporting
  // only the direct-mixin count would understate the security guarantee.
  final permissionValidationDirect = _countMatching(
      cache, repos, RegExp(r'\bwith[^;{]*\bPermissionValidationMixin\b'));
  final permissionValidationEffective = _countMatching(
      cache,
      repos,
      RegExp(r'\bextends BaseFirebaseRepository<|'
          r'\bwith[^;{]*\bPermissionValidationMixin\b'));
  final baseViewModel =
      _countMatching(cache, viewmodels, RegExp(r'\bextends BaseViewModel\b'));

  // SerializationUtils is invoked per-call, not per-class.
  final serUtilsPattern = RegExp(r'SerializationUtils\.safe[A-Za-z]+\(');
  final serUtilsCallSites =
      _countAllOccurrences(cache, dartFiles, serUtilsPattern);
  final serUtilsFiles = _countMatching(cache, dartFiles, serUtilsPattern);

  final serviceClassCount = services.length;
  final repoClassCount = repos.length;
  final vmClassCount = viewmodels.length;

  final report = _buildReport(
    measuredAt: DateTime.now().toUtc(),
    serviceClassCount: serviceClassCount,
    baseServiceAdoption: baseService,
    errorHandlingMixinAdoption: errorHandlingMixin,
    repoClassCount: repoClassCount,
    baseFirebaseRepoAdoption: baseFirebaseRepo,
    permissionValidationDirect: permissionValidationDirect,
    permissionValidationEffective: permissionValidationEffective,
    vmClassCount: vmClassCount,
    baseViewModelAdoption: baseViewModel,
    serUtilsCallSites: serUtilsCallSites,
    serUtilsFiles: serUtilsFiles,
    totalDartFiles: dartFiles.length,
  );

  final outFile = File('docs/architecture/adoption-status.md');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(report);

  stdout.writeln('Wrote ${outFile.path}');
}

bool _isUnder(File f, String pathFragment) {
  final fragment = pathFragment.replaceAll('/', Platform.pathSeparator);
  return f.path.contains(fragment);
}

int _countMatching(
    Map<String, String> cache, List<File> files, RegExp pattern) {
  var n = 0;
  for (final f in files) {
    if (pattern.hasMatch(cache[f.path] ?? '')) n++;
  }
  return n;
}

int _countAllOccurrences(
    Map<String, String> cache, List<File> files, RegExp pattern) {
  var n = 0;
  for (final f in files) {
    n += pattern.allMatches(cache[f.path] ?? '').length;
  }
  return n;
}

String _read(File f) {
  try {
    return f.readAsStringSync();
  } catch (_) {
    return '';
  }
}

String _pct(int numerator, int denominator) {
  if (denominator == 0) return 'n/a';
  final p = (numerator / denominator) * 100;
  return '${p.toStringAsFixed(1)}% ($numerator/$denominator)';
}

String _buildReport({
  required DateTime measuredAt,
  required int serviceClassCount,
  required int baseServiceAdoption,
  required int errorHandlingMixinAdoption,
  required int repoClassCount,
  required int baseFirebaseRepoAdoption,
  required int permissionValidationDirect,
  required int permissionValidationEffective,
  required int vmClassCount,
  required int baseViewModelAdoption,
  required int serUtilsCallSites,
  required int serUtilsFiles,
  required int totalDartFiles,
}) {
  final iso = measuredAt.toIso8601String();
  return '''
# Architecture adoption status

> Auto-generated by `tools/measure_adoption.dart`. Do not hand-edit — re-run
> the tool and commit the result. Inline adoption % anywhere else in the repo
> is forbidden by `tools/check_no_inline_adoption_pct.sh` (BUT-776).

**Measured:** $iso (UTC).
**Source ticket:** BUT-810. **Tool:** `tools/measure_adoption.dart`.
**Scope:** every `*.dart` file under `lib/` except `lib/site-packages/`.

## Results

| Axis | Adoption | Pool |
| ---- | -------- | ---- |
| `extends BaseService` (services) | ${_pct(baseServiceAdoption, serviceClassCount)} | `lib/services/` classes |
| `with ErrorHandlingMixin` (services) | ${_pct(errorHandlingMixinAdoption, serviceClassCount)} | `lib/services/` classes |
| `extends BaseFirebaseRepository` (repos) | ${_pct(baseFirebaseRepoAdoption, repoClassCount)} | `lib/repositories/firebase/` classes |
| `PermissionValidationMixin` effective coverage (repos) | ${_pct(permissionValidationEffective, repoClassCount)} | `lib/repositories/firebase/` classes — direct `with` OR via BFR |
| `PermissionValidationMixin` direct adoption (repos) | ${_pct(permissionValidationDirect, repoClassCount)} | `lib/repositories/firebase/` classes — base classes / non-BFR adopters |
| `extends BaseViewModel` (viewmodels) | ${_pct(baseViewModelAdoption, vmClassCount)} | `lib/viewmodels/` classes |
| `SerializationUtils.safe*(` (call sites) | $serUtilsCallSites | $serUtilsFiles files use it |

**Total Dart files under `lib/` (excl. `site-packages/`):** $totalDartFiles.

### Why `PermissionValidationMixin` has two rows

The mixin is applied to `BaseFirebaseRepository` itself
(`lib/repositories/firebase/base_firebase_repository.dart:17`), so every
concrete repo extending BFR inherits it transitively. The **effective
coverage** row is the security-relevant number — it answers "what % of
Firebase repos have `validatePermission*` checks available." The **direct
adoption** row counts only files that name the mixin in their `with` clause
(typically base classes, or non-BFR repos that opted in manually); it's an
implementation detail, not a security signal.

## How to use

When you need to cite an adoption percentage in a doc, prompt, or PR
description, **link to this file's relative path** instead of inlining the
number:

```markdown
Adoption: see [docs/architecture/adoption-status.md](./adoption-status.md).
```

The CI guard from BUT-776 fails the build if any document under
`docs/analysis/prompts/` or the orchestrator inlines a percentage that
should reference this file.

## Caveats

- "Pool" denominators count files by canonical filename suffix
  (`_service.dart`, `_repository.dart`, `_viewmodel.dart`) under the
  matching `lib/` subtree. Pure helper files that don't follow the suffix
  are excluded — same convention `lib/services/CLAUDE.md` uses for its
  "~98% adoption" claim.
- `BaseFirebaseRepository` adoption only counts `lib/repositories/firebase/`.
  The `lib/repositories/interfaces/` directory is structurally exempt.
- `ErrorHandlingMixin` adoption is measured against `with` clauses; classes
  that compose error handling via inheritance from a base that already mixes
  it in (e.g. `BaseFirebaseRepository`) are not double-counted.
''';
}
