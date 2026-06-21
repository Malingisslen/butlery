/// Web implementation — generates clean HTML and opens browser print dialog.
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/print/recipe_print_html_builder.dart';

Future<void> printRecipeHtml(Recipe recipe) async {
  final html = buildRecipePrintHtml(recipe);
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
