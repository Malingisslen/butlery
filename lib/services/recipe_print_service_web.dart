/// Web implementation — generates clean HTML and opens browser print dialog.
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:butlery/models/recipe_unified.dart';

Future<void> printRecipeHtml(Recipe recipe) async {
  final html = _buildRecipeHtml(recipe);
  final encoded = Uri.dataFromString(
    html,
    mimeType: 'text/html',
    encoding: utf8,
  );
  final newWindow = web.window.open(encoded.toString(), '_blank');
  // Trigger print after content loads
  if (newWindow != null) {
    newWindow.addEventListener(
      'load',
      (web.Event _) {
        newWindow.print();
      }.toJS,
    );
  }
}

String _buildRecipeHtml(Recipe recipe) {
  final ingredients = recipe.ingredients.map((i) => '<li>$i</li>').join('\n');
  final instructions = recipe.instructions
      .asMap()
      .entries
      .map((e) => '<li>${e.value}</li>')
      .join('\n');

  final meta = <String>[];
  if (recipe.portions != null) meta.add('${recipe.portions} portioner');
  if (recipe.timeMinutes != null) meta.add('${recipe.timeMinutes} min');

  return '''<!DOCTYPE html>
<html lang="sv">
<head>
<meta charset="UTF-8">
<title>${_esc(recipe.title)}</title>
<style>
  body { font-family: Georgia, serif; max-width: 700px; margin: 40px auto; padding: 0 20px; color: #333; }
  h1 { font-size: 28px; margin-bottom: 4px; }
  .meta { color: #666; font-size: 14px; margin-bottom: 24px; }
  h2 { font-size: 18px; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
  li { margin-bottom: 6px; line-height: 1.5; }
  ol li { margin-bottom: 12px; }
  .source { font-size: 12px; color: #999; margin-top: 32px; }
  @media print { body { margin: 0; } }
</style>
</head>
<body>
<h1>${_esc(recipe.title)}</h1>
${meta.isNotEmpty ? '<p class="meta">${meta.join(' · ')}</p>' : ''}
<h2>Ingredienser</h2>
<ul>$ingredients</ul>
<h2>Instruktioner</h2>
<ol>$instructions</ol>
${recipe.sourceUrl != null ? '<p class="source">Källa: ${_esc(recipe.sourceUrl!)}</p>' : ''}
<p class="source">Utskrivet från Butlery</p>
</body>
</html>''';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
