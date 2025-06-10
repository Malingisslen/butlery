// lib/viewmodels/text_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';

/// ViewModel för text-baserad receptimport (sociala medier, OCR, etc)
class TextImportViewModel extends ChangeNotifier {
  final _uuid = const Uuid();

  // State
  String _inputText = '';
  bool _isParsing = false;
  String? _error;
  Recipe? _parsedRecipe;

  // Getters
  String get inputText => _inputText;
  bool get isParsing => _isParsing;
  String? get error => _error;
  bool get hasError => _error != null;
  Recipe? get parsedRecipe => _parsedRecipe;
  bool get hasParsedRecipe => _parsedRecipe != null;
  bool get canParse => _inputText.trim().isNotEmpty;

  /// Uppdatera input-text
  void updateInputText(String text) {
    _inputText = text;
    _error = null;
    notifyListeners();
  }

  /// Rensa all input
  void clearInput() {
    _inputText = '';
    _error = null;
    _parsedRecipe = null;
    notifyListeners();
  }

  /// Parsa text till recept
  Future<bool> parseText() async {
    final input = _inputText.trim();
    if (input.isEmpty) {
      _setError('Ange text att tolka');
      return false;
    }

    _setParsing(true);
    _error = null;

    try {
      // Simulera parsing-tid för bättre UX
      await Future.delayed(const Duration(milliseconds: 300));

      _parsedRecipe = _parseTextToRecipe(input);

      if (_parsedRecipe == null) {
        throw Exception('Kunde inte tolka receptet från texten');
      }

      return true;
    } catch (e) {
      _setError('Kunde inte tolka text: ${e.toString()}');
      return false;
    } finally {
      _setParsing(false);
    }
  }

  /// Parsar text till Recipe-objekt (förbättrad logik)
  Recipe? _parseTextToRecipe(String input) {
    final lines = input.split('\n');
    final ingredients = <String>[];
    final instructions = <String>[];

    bool foundStart = false;
    bool foundInstructions = false;

    // Triggers för att hitta start/stop i texten
    final lowerTriggers = [
      'gör så här',
      'gör såhär',
      'så här gör du',
      'stek',
      'koka',
      'ugnen',
      'blanda',
    ];
    final ingredientStartTriggers = ['recept', 'ingredienser'];
    final rubrikord = ['instruktion', 'tillbehör', 'sås', 'servera', 'annat'];
    final skipWords = ['spara', 'testa', 'följ', 'likea'];
    final dishIndicators = [
      'kyckling',
      'fläsk',
      'pasta',
      'gryta',
      'tacos',
      'lax',
      'sallad',
    ];

    String normalizeText(String txt) {
      // Ta bort "fancy" unicode-bokstäver och flera mellanslag
      final withoutFancy = txt.replaceAllMapped(
        RegExp(r'[\u{1D400}-\u{1D7FF}]', unicode: true),
        (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0x1D400 + 0x41),
      );
      return withoutFancy.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // 1) Extrahera titel ur de första raderna
    String? extractedTitle;
    for (final line in lines.take(6)) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final norm = normalizeText(t);
      final lower = norm.toLowerCase();

      if (skipWords.any((w) => lower.contains(w))) continue;
      if (dishIndicators.any((w) => lower.contains(w)) || norm.length < 40) {
        // Rensa specialtecken och korta av till max 6 ord
        final cleaned = norm.replaceAll(
          RegExp(r'[^\p{L}\p{N} ,.-]', unicode: true),
          '',
        );
        extractedTitle = cleaned.split(' ').take(6).join(' ');
        break;
      }
    }

    // 2) Loopa igenom alla rader och dela in i ingredienser / instruktioner
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;
      final norm = normalizeText(raw);
      final lower = norm.toLowerCase();

      // Hoppa över rubriker, korta versaler etc
      if (rubrikord.any((r) => lower.startsWith(r)) ||
          (norm == norm.toUpperCase() && norm.split(' ').length <= 3)) {
        continue;
      }

      // Leta efter start på ingrediens‐avsnitt
      if (!foundStart) {
        final isTrigger = ingredientStartTriggers.any(
          (tr) => lower.contains(tr) || lower.startsWith(tr),
        );
        final looksLikeQty = RegExp(r'^\d').hasMatch(norm);
        if (isTrigger || looksLikeQty) {
          foundStart = true;
          if (isTrigger) continue;
        } else {
          continue;
        }
      }

      // När vi ser en matlagnings-trigger börjar vi samla instruktioner
      if (!foundInstructions && lowerTriggers.any((tr) => lower.contains(tr))) {
        foundInstructions = true;
      }

      if (!foundInstructions) {
        ingredients.add(norm);
      } else {
        // Dela instruktion med sats-boundary
        final parts =
            norm
                .split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÅÄÖ])'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
        instructions.addAll(parts);
      }
    }

    // Om vi inte hittade något vettigt, returnera null
    if (ingredients.isEmpty && instructions.isEmpty) {
      return null;
    }

    // 3) Skapa Recipe-objektet
    return Recipe(
      id: _uuid.v4(),
      title:
          extractedTitle?.isNotEmpty == true ? extractedTitle! : 'Nytt recept',
      description: '',
      portions: null,
      timeMinutes: null,
      ingredients:
          ingredients.isEmpty ? ['Lägg till ingredienser'] : ingredients,
      instructions:
          instructions.isEmpty ? ['Lägg till instruktioner'] : instructions,
      tags: [],
      rating: null,
      imageUrl: null,
      mealType: 'Middag', // Default-typ, kan ändras i redigera-vyn
    );
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Private methods
  void _setParsing(bool value) {
    _isParsing = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
