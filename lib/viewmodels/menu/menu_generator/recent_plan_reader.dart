import 'package:clock/clock.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';

/// Collects recipe IDs used in the last 1-2 weekly plans so generation can
/// down-weight them (BUT-1318). Returns an empty set with no history (first
/// menu ever) or when no plan service is wired — generation then uses the
/// full pool unchanged. Errors are swallowed: a recent-plan read failure
/// must never block menu generation, but it is reported in `readFailed` so
/// the screen can say that dishes may repeat.
Future<({Set<String> ids, bool readFailed})> recentlyUsedRecipeIds(
  WeeklyMenuPlanService? service,
) async {
  if (service == null) return (ids: const <String>{}, readFailed: false);
  try {
    final now = clock.now();
    final thisWeek = IsoWeekUtils.weekStartOf(now);
    final lastWeek = thisWeek.subtract(const Duration(days: 7));
    // Read this week + last week only (1-2 plans) — bounded, cheap, and the
    // weeks the user is most likely repeating from.
    final reads = await Future.wait([
      service.readWeek(thisWeek),
      service.readWeek(lastWeek),
    ]);
    final ids = <String>{};
    for (final read in reads) {
      for (final entry in read.plan.entries) {
        ids.add(entry.recipeId);
      }
    }
    return (ids: ids, readFailed: reads.any((r) => r.readFailed));
  } catch (e) {
    AppLogger.warning('Recent-plan dedup skipped: $e');
    return (ids: const <String>{}, readFailed: true);
  }
}
