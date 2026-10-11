import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/whats_new/whats_new_catalog.dart';

class WhatsNewService {
  WhatsNewService({
    required SharedPreferences prefs,
    required String currentVersion,
    List<WhatsNewRelease> catalog = whatsNewReleases,
  }) : _prefs = prefs,
       _currentVersion = currentVersion,
       _catalog = catalog;

  static const String lastSeenKey = 'whats_new_last_seen_version_v1';
  static const int maxItems = 5;

  final SharedPreferences _prefs;
  final String _currentVersion;
  final List<WhatsNewRelease> _catalog;

  /// Releases the user has not seen, newest first, trimmed to [maxItems]
  /// items in total. Records the current version as seen on every call, so a
  /// release is announced at most once.
  Future<List<WhatsNewRelease>> releasesToShow() async {
    final current = _parse(_currentVersion);
    if (current == null) return const [];

    final storedRaw = _prefs.getString(lastSeenKey);
    final stored = storedRaw == null ? null : _parse(storedRaw);
    await _prefs.setString(lastSeenKey, _currentVersion);

    // No usable stored version means a first install: nothing is new to them.
    if (stored == null || _compare(stored, current) >= 0) return const [];

    final due =
        _catalog.where((r) {
          final v = _parse(r.version);
          return v != null &&
              _compare(v, stored) > 0 &&
              _compare(v, current) <= 0;
        }).toList()..sort(
          (a, b) => _compare(_parse(b.version)!, _parse(a.version)!),
        );

    final result = <WhatsNewRelease>[];
    var remaining = maxItems;
    for (final release in due) {
      if (remaining == 0) break;
      final items = release.items.take(remaining).toList();
      if (items.isEmpty) continue;
      remaining -= items.length;
      result.add(WhatsNewRelease(version: release.version, items: items));
    }
    return result;
  }

  /// The newest release not newer than [currentVersion], or null.
  static WhatsNewRelease? latestReleaseUpTo(
    List<WhatsNewRelease> catalog,
    String currentVersion,
  ) {
    final current = _parse(currentVersion);
    if (current == null) return null;
    WhatsNewRelease? best;
    List<int>? bestVersion;
    for (final release in catalog) {
      final v = _parse(release.version);
      if (v == null || _compare(v, current) > 0) continue;
      if (bestVersion == null || _compare(v, bestVersion) > 0) {
        best = release;
        bestVersion = v;
      }
    }
    return best;
  }

  static List<int>? _parse(String version) {
    final parts = version.split('+').first.trim().split('.');
    if (parts.isEmpty || parts.length > 3) return null;
    final numbers = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0) return null;
      numbers.add(n);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers;
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}
