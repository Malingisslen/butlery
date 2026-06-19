import 'package:butlery/models/admin/recipe_stats.dart';

/// A passive, partially-populated snapshot of already-fetched admin data for a
/// time range. The [MetricsAssembler] fills only the category slices whose
/// metrics are on screen (lazy by category — a mega-fetch would re-run the
/// expensive recipe scan on every tab). Resolvers read their own slice and
/// assume the assembler guaranteed its presence before calling them.
///
/// Slices are added here as each tab migrates onto the registry.
class InsightsData {
  final RecipeStats? recipes;

  const InsightsData({this.recipes});
}
