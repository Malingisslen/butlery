/// Read-model for the admin recipe-overview tab: total recipe count and a
/// breakdown by how each recipe entered the app. Derived from the
/// `core.sourceArtefact.type` field on each recipe document (see
/// [SourceArtefactType]); recipes without the field count as [manual].

/// How a recipe was added, grouped for the admin breakdown.
enum RecipeImportMethod {
  /// Web URL import.
  url,

  /// Photo / OCR import.
  photo,

  /// Pasted plain text.
  textPaste,

  /// Social captions/transcripts (Instagram, TikTok, YouTube).
  social,

  /// Manual entry, or recipes predating the source-artefact field.
  manual,
}

class RecipeStats {
  final int total;
  final Map<RecipeImportMethod, int> byMethod;

  const RecipeStats({required this.total, required this.byMethod});

  int count(RecipeImportMethod method) => byMethod[method] ?? 0;

  /// Recipes that came in through any import path (everything but [manual]).
  int get imported => total - count(RecipeImportMethod.manual);
}
