/// BUT-1520 C6/C7: the production pool key measured against the cookbook corpus.
///
/// Pure `dart:io` + `dart:convert`; the keyer is injected so the CLI passes the
/// production `CanonicalPoolKey.compute` and tests pass a stub.
///
/// The corpus may never leave Malin's machine (docs/architecture/
/// ACCEPTED_DEVIATIONS.md, "Kokboksprovet"), so [formatSummary] prints totals
/// only. Titles and page ids appear solely in [formatDetail], which the CLI
/// prints behind an explicit flag for local review.
library;

import 'dart:convert';
import 'dart:io';

typedef PoolKeyer =
    String? Function({
      required String title,
      required List<String> ingredients,
    });

/// One recipe as the key sees it: a title and the raw ingredient lines, which
/// is the shape production keys on (`recipe.core.ingredients`).
class KeyedRecipe {
  final String pageId;
  final String title;
  final List<String> lines;

  const KeyedRecipe({
    required this.pageId,
    required this.title,
    required this.lines,
  });

  /// Two photographs of the same page give equal fingerprints; that is a
  /// duplicate in the corpus, not a false merge.
  String get fingerprint {
    final sorted = lines.map((l) => l.trim().toLowerCase()).toList()..sort();
    return '${title.trim().toLowerCase()}\n${sorted.join('\n')}';
  }
}

enum GoldSource { verified, proposed }

class CorpusPage {
  final String pageId;
  final GoldSource goldSource;
  final List<KeyedRecipe> gold;
  final List<KeyedRecipe> drafts;

  const CorpusPage({
    required this.pageId,
    required this.goldSource,
    required this.gold,
    required this.drafts,
  });
}

class PageLoad {
  final List<CorpusPage> pages;

  /// Page directories with no usable answer key.
  final int unlabeled;

  const PageLoad(this.pages, this.unlabeled);
}

final _recipeBlock = RegExp(r'^recipe-\d+$');

/// Walks [root] for `gold.json`, `gold.proposed.json` and `draft.json`, grouping
/// a nested `recipe-NN/` block under its page directory. Directories whose name
/// starts with `_` or `.` (reports, scratch) are skipped.
///
/// A page uses `gold.json` only when every `gold.json` on it is verified;
/// otherwise it falls back to `gold.proposed.json`, and a page with neither
/// counts as unlabeled.
PageLoad loadPages(Directory root) {
  final byPage = <String, List<File>>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = entity.path.substring(root.path.length).replaceAll('\\', '/');
    final segments = rel.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) continue;
    if (segments.any((s) => s.startsWith('_') || s.startsWith('.'))) continue;
    final name = segments.last;
    if (name != 'gold.json' &&
        name != 'gold.proposed.json' &&
        name != 'draft.json') {
      continue;
    }
    var dirSegments = segments.sublist(0, segments.length - 1);
    if (_recipeBlock.hasMatch(dirSegments.last) && dirSegments.length > 1) {
      dirSegments = dirSegments.sublist(0, dirSegments.length - 1);
    }
    byPage.putIfAbsent(dirSegments.join('/'), () => []).add(entity);
  }

  final pages = <CorpusPage>[];
  var unlabeled = 0;
  for (final pageId in byPage.keys.toList()..sort()) {
    final files = byPage[pageId]!;
    List<File> named(String n) =>
        files.where((f) => f.uri.pathSegments.last == n).toList();

    final drafts = [
      for (final f in named('draft.json')) ..._readRecipes(f, pageId).recipes,
    ];

    final goldFiles = named('gold.json').map((f) => _readRecipes(f, pageId));
    final allVerified =
        goldFiles.isNotEmpty &&
        goldFiles.every((g) => g.allVerified && g.recipes.isNotEmpty);
    if (allVerified) {
      pages.add(
        CorpusPage(
          pageId: pageId,
          goldSource: GoldSource.verified,
          gold: [for (final g in goldFiles) ...g.recipes],
          drafts: drafts,
        ),
      );
      continue;
    }
    final proposed = named('gold.proposed.json');
    if (proposed.isNotEmpty) {
      pages.add(
        CorpusPage(
          pageId: pageId,
          goldSource: GoldSource.proposed,
          gold: [
            for (final f in proposed) ..._readRecipes(f, pageId).recipes,
          ],
          drafts: drafts,
        ),
      );
      continue;
    }
    unlabeled++;
  }
  return PageLoad(pages, unlabeled);
}

class _Read {
  final List<KeyedRecipe> recipes;
  final bool allVerified;
  const _Read(this.recipes, this.allVerified);
}

/// Accepts one recipe object, a list of them, or an object holding the list
/// under `recipes` / `entries`. A malformed file reads as empty.
_Read _readRecipes(File file, String pageId) {
  Object? json;
  try {
    json = jsonDecode(file.readAsStringSync());
  } catch (_) {
    return const _Read([], false);
  }
  final maps = <Map>[];
  if (json is List) {
    maps.addAll(json.whereType<Map>());
  } else if (json is Map) {
    final nested = json['recipes'] ?? json['entries'];
    if (nested is List) {
      maps.addAll(nested.whereType<Map>());
    } else {
      maps.add(json);
    }
  }
  final recipes = <KeyedRecipe>[];
  var allVerified = maps.isNotEmpty;
  for (final m in maps) {
    if (m['verified'] != true) allVerified = false;
    final lines = <String>[];
    final ingredients = m['ingredients'];
    if (ingredients is List) {
      for (final i in ingredients) {
        final line = i is Map
            ? (i['originalLine'] ?? i['name'])?.toString()
            : i?.toString();
        if (line != null && line.trim().isNotEmpty) lines.add(line);
      }
    }
    recipes.add(
      KeyedRecipe(
        pageId: pageId,
        title: m['title']?.toString() ?? '',
        lines: lines,
      ),
    );
  }
  return _Read(recipes, allVerified);
}

/// A key shared by recipes that are not the same recipe.
class Collision {
  final String key;
  final List<KeyedRecipe> members;
  const Collision(this.key, this.members);
}

class PoolKeyCorpusResult {
  final int pages;
  final int unlabeledPages;
  final int pagesVerified;
  final int pagesProposed;
  final int goldRecipes;
  final int goldKeyed;

  /// Gold recipes with a key whose page also has a draft with the same key.
  final int draftSameKey;

  /// Gold recipes with a key whose page has drafts, none with that key.
  final int draftOtherKey;

  /// Gold recipes with a key on a page with no draft at all.
  final int noDraft;

  /// Keys shared by byte-identical recipes (one page photographed twice).
  final int duplicateGroups;
  final List<Collision> goldCollisions;
  final List<Collision> draftCollisions;

  const PoolKeyCorpusResult({
    required this.pages,
    required this.unlabeledPages,
    required this.pagesVerified,
    required this.pagesProposed,
    required this.goldRecipes,
    required this.goldKeyed,
    required this.draftSameKey,
    required this.draftOtherKey,
    required this.noDraft,
    required this.duplicateGroups,
    required this.goldCollisions,
    required this.draftCollisions,
  });

  bool get preliminary => pagesProposed > 0;
}

PoolKeyCorpusResult measure(PageLoad load, PoolKeyer keyer) {
  String? keyOf(KeyedRecipe r) => keyer(title: r.title, ingredients: r.lines);

  var goldRecipes = 0, goldKeyed = 0, same = 0, other = 0, noDraft = 0;
  final goldByKey = <String, List<KeyedRecipe>>{};
  final draftByKey = <String, List<KeyedRecipe>>{};

  for (final page in load.pages) {
    final draftKeys = <String>{};
    for (final d in page.drafts) {
      final k = keyOf(d);
      if (k == null) continue;
      draftKeys.add(k);
      draftByKey.putIfAbsent(k, () => []).add(d);
    }
    for (final g in page.gold) {
      goldRecipes++;
      final k = keyOf(g);
      if (k == null) continue;
      goldKeyed++;
      goldByKey.putIfAbsent(k, () => []).add(g);
      if (page.drafts.isEmpty) {
        noDraft++;
      } else if (draftKeys.contains(k)) {
        same++;
      } else {
        other++;
      }
    }
  }

  var duplicateGroups = 0;
  final goldCollisions = <Collision>[];
  for (final e in goldByKey.entries) {
    if (e.value.length < 2) continue;
    if (e.value.map((r) => r.fingerprint).toSet().length == 1) {
      duplicateGroups++;
    } else {
      goldCollisions.add(Collision(e.key, e.value));
    }
  }

  // A draft key shared across pages is a false merge only when those pages'
  // answer keys disagree; pages whose gold shares that key, or whose gold is
  // the same recipe photographed twice, are a duplicate or already reported
  // above.
  final goldKeysByPage = <String, Set<String>>{};
  for (final e in goldByKey.entries) {
    for (final r in e.value) {
      goldKeysByPage.putIfAbsent(r.pageId, () => {}).add(e.key);
    }
  }
  final goldPrintsByPage = {
    for (final page in load.pages)
      page.pageId: {for (final g in page.gold) g.fingerprint},
  };
  final draftCollisions = <Collision>[];
  for (final e in draftByKey.entries) {
    final pageIds = e.value.map((r) => r.pageId).toSet();
    if (pageIds.length < 2) continue;
    final sharedPrints = pageIds
        .map((p) => goldPrintsByPage[p] ?? const <String>{})
        .reduce((a, b) => a.intersection(b));
    final explained =
        sharedPrints.isNotEmpty ||
        pageIds.every((p) => goldKeysByPage[p]?.contains(e.key) ?? false);
    if (!explained) draftCollisions.add(Collision(e.key, e.value));
  }

  return PoolKeyCorpusResult(
    pages: load.pages.length,
    unlabeledPages: load.unlabeled,
    pagesVerified: load.pages
        .where((p) => p.goldSource == GoldSource.verified)
        .length,
    pagesProposed: load.pages
        .where((p) => p.goldSource == GoldSource.proposed)
        .length,
    goldRecipes: goldRecipes,
    goldKeyed: goldKeyed,
    draftSameKey: same,
    draftOtherKey: other,
    noDraft: noDraft,
    duplicateGroups: duplicateGroups,
    goldCollisions: goldCollisions,
    draftCollisions: draftCollisions,
  );
}

String _pct(int n, int d) =>
    d == 0 ? '-' : '${(100 * n / d).toStringAsFixed(1)} %';

/// Totals only: safe to paste into the runbook or a PR.
String formatSummary(PoolKeyCorpusResult r) {
  final verdict = r.goldCollisions.isNotEmpty || r.draftCollisions.isNotEmpty
      ? 'STOP (false-merge candidates)'
      : r.preliminary
      ? 'PRELIMINARY PASS (answer keys not all verified)'
      : 'PASS';
  final pages = r.pages, verified = r.pagesVerified, proposed = r.pagesProposed;
  final heldOut = r.goldRecipes - r.goldKeyed;
  final sameShare = _pct(r.draftSameKey, r.draftSameKey + r.draftOtherKey);
  final c7 =
      'same key: ${r.draftSameKey} ($sameShare); other or no key: '
      '${r.draftOtherKey}; page without draft: ${r.noDraft}';
  final c6 =
      'answer keys ${r.goldCollisions.length}, OCR drafts '
      '${r.draftCollisions.length}; duplicate photos: ${r.duplicateGroups}';
  return (StringBuffer()
        ..writeln('Pool key vs cookbook corpus (BUT-1520 C6/C7)')
        ..writeln(
          '  pages: $pages (verified $verified, proposed $proposed); '
          'unlabeled: ${r.unlabeledPages}',
        )
        ..writeln(
          '  answer-key recipes: ${r.goldRecipes}; keyed: ${r.goldKeyed} '
          '(${_pct(r.goldKeyed, r.goldRecipes)}); held out: $heldOut',
        )
        ..writeln('  C7 OCR draft gives the $c7')
        ..writeln('  C6 false-merge candidates: $c6')
        ..write('  verdict: $verdict'))
      .toString();
}

/// Titles and page ids of every candidate. LOCAL REVIEW ONLY: never paste it
/// into the repo, a PR, a ticket or a chat.
String formatDetail(PoolKeyCorpusResult r) {
  final out = StringBuffer('LOCAL ONLY - do not paste anywhere\n');
  void dump(String label, List<Collision> list) {
    for (var i = 0; i < list.length; i++) {
      out.writeln('$label #${i + 1} ${list[i].key}');
      for (final m in list[i].members) {
        out.writeln('    ${m.pageId}: ${m.title}');
      }
    }
  }

  dump('answer-key collision', r.goldCollisions);
  dump('draft collision', r.draftCollisions);
  return out.toString();
}
