import 'package:butlery/models/admin/engagement_stats.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/models/parsing/site_config.dart';

/// A passive, partially-populated snapshot of already-fetched admin data for a
/// time range. The [MetricsAssembler] fills only the category slices whose
/// metrics are on screen (lazy by category — a mega-fetch would re-run the
/// expensive recipe scan on every tab). Resolvers read their own slice and
/// assume the assembler guaranteed its presence before calling them.
///
/// Slices are added here as each tab migrates onto the registry.
class InsightsData {
  final RecipeStats? recipes;

  /// All site-config rollups (per-domain cumulative success/failure counts).
  final List<SiteConfig>? importConfigs;

  /// User count + recent daily feature-retention aggregates.
  final EngagementRaw? engagement;

  const InsightsData({this.recipes, this.importConfigs, this.engagement});
}
