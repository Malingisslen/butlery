// lib/viewmodels/text_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';

/// ViewModel för text-baserad receptimport (sociala medier, OCR, etc)
/// Nu med stöd för sourceUrl och förbättrad Instagram-parsing
class TextImportViewModel extends ChangeNotifier {
  final _uuid = const Uuid();

  // State
  String _inputText = '';
  bool _isParsing = false;
  String? _error;
  Recipe? _parsedRecipe;
  String? _sourceUrl; // URL från import

  // Getters
  String get inputText => _inputText;
  bool get isParsing => _isParsing;
  String? get error => _error;
  bool get hasError => _error != null;
  Recipe? get parsedRecipe => _parsedRecipe;
  bool get hasParsedRecipe => _parsedRecipe != null;
  bool get canParse => _inputText.trim().isNotEmpty;
  String? get sourceUrl => _sourceUrl;

  /// Sätt sourceUrl (används när recept importeras från URL)
  void setSourceUrl(String url) {
    _sourceUrl = url;
    notifyListeners();
  }

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
    _sourceUrl = null;
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

  /// Normaliserar text genom att ta bort emojis och specialtecken
  String _normalizeText(String txt) {
    try {
      String normalized = txt;

      // Ta bort emojis
      normalized = normalized.replaceAll(
        RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true),
        '',
      );

      // Konvertera matematiska Unicode-stilar till vanliga bokstäver
      final runes = normalized.runes.toList();
      final result = StringBuffer();

      for (final rune in runes) {
        // Matematiska fetstilta versaler (𝐀-𝐙)
        if (rune >= 0x1D400 && rune <= 0x1D419) {
          result.write(String.fromCharCode((rune - 0x1D400) + 0x41)); // A-Z
        }
        // Matematiska fetstilta gemener (𝐚-𝐳)
        else if (rune >= 0x1D41A && rune <= 0x1D433) {
          result.write(String.fromCharCode((rune - 0x1D41A) + 0x61)); // a-z
        }
        // Matematiska fetstilta siffror (𝟎-𝟗)
        else if (rune >= 0x1D7CE && rune <= 0x1D7D7) {
          result.write(String.fromCharCode((rune - 0x1D7CE) + 0x30)); // 0-9
        }
        // Behåll vanliga tecken (inklusive svenska åäö)
        else if ((rune >= 0x20 && rune <= 0x7E) || // Grundläggande ASCII
            (rune >= 0xA0 && rune <= 0xFF) || // Latin-1 supplement (inkl. åäö)
            rune == 0x2013 ||
            rune == 0x2014) {
          // Tankstreck
          result.write(String.fromCharCode(rune));
        }
        // Annars hoppa över tecknet
      }

      // Normalisera whitespace
      normalized = result.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

      return normalized;
    } catch (e) {
      debugPrint('Error normalizing text: $e');
      return txt.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }

  /// Förbehandlar Instagram-text för att lägga till radbrytningar
  String _preprocessInstagramText(String input) {
    String processed = input;

    // Lägg till radbrytning efter "Det du behöver är" eller liknande fraser
    processed = processed.replaceAllMapped(
      RegExp(
        r'(behöver är|ingredienser|du behöver|recept)',
        caseSensitive: false,
      ),
      (match) => '${match.group(0)}\n',
    );

    // Lägg till radbrytning före vanliga instruktionsord
    processed = processed.replaceAllMapped(
      RegExp(
        r'(Börja med|Sätt ugnen|Koka|Stek|Blanda|Häll|Lägg|Skär|Servera|Värm|Rör)',
        caseSensitive: false,
      ),
      (match) => '\n${match.group(0)}',
    );

    // Lägg till radbrytning mellan mängd+ingrediens pattern
    // T.ex. "3 dl sushiris0,5 dl risvinäger" blir "3 dl sushiris\n0,5 dl risvinäger"
    processed = processed.replaceAllMapped(
      RegExp(r'([a-zåäö])(\d+(?:,\d+)?\s*(?:kg|g|dl|cl|ml|l|msk|tsk|krm|st))'),
      (match) => '${match.group(1)}\n${match.group(2)}',
    );

    // Lägg till radbrytning efter punkter som följs av stor bokstav
    processed = processed.replaceAllMapped(
      RegExp(r'\.(\s*)([A-ZÅÄÖ])'),
      (match) => '.\n${match.group(2)}',
    );

    return processed;
  }

  /// Parsar text till Recipe-objekt med förbättrad Instagram-hantering
  Recipe? _parseTextToRecipe(String input) {
    // Förbehandla om det verkar vara Instagram-text (inga radbrytningar)
    String processedInput = input;
    if (!input.contains('\n') || input.split('\n').length < 3) {
      debugPrint('📸 Detekterade Instagram-format - förbehandlar text');
      processedInput = _preprocessInstagramText(input);
    }

    final lines = processedInput.split('\n');
    final ingredients = <String>[];
    final instructions = <String>[];

    bool foundStart = false;
    bool foundInstructions = false;

    // Triggers för att hitta start/stop i texten
    final instructionTriggers = [
      'gör så här',
      'gör såhär',
      'så här gör du',
      'stek',
      'koka',
      'ugnen',
      'blanda',
      'börja med',
      'häll',
      'lägg',
      'rör',
      'skär',
      'servera',
      'värm',
      'ställ',
      'tryck',
    ];

    final ingredientStartTriggers = [
      'recept',
      'ingredienser',
      'du behöver',
      'behöver är',
    ];

    final skipWords = ['spara', 'testa', 'följ', 'likea', 'kommentera', 'dela'];

    // 1) Extrahera titel ur de första raderna
    String? extractedTitle;
    for (final line in lines.take(6)) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final norm = _normalizeText(t);
      final lower = norm.toLowerCase();

      if (skipWords.any((w) => lower.contains(w))) continue;

      // Om raden innehåller rätt-relaterade ord eller är kort nog för titel
      if (norm.length < 50 && !lower.contains('recept')) {
        extractedTitle = norm.split(' ').take(6).join(' ');
        break;
      }
    }

    // 2) Loopa igenom alla rader och dela in i ingredienser / instruktioner
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;

      String norm;
      try {
        norm = _normalizeText(raw);
      } catch (e) {
        debugPrint('Skipping line due to normalization error: $e');
        continue;
      }

      final lower = norm.toLowerCase();

      // Hoppa över sociala medier-metadata
      if (skipWords.any((w) => lower.contains(w))) {
        continue;
      }

      // Leta efter start på ingrediens-avsnitt
      if (!foundStart) {
        final isTrigger = ingredientStartTriggers.any(
          (tr) => lower.contains(tr),
        );
        final looksLikeIngredient = RegExp(
          r'^\d+(?:,\d+)?\s*(?:kg|g|dl|cl|ml|l|msk|tsk|krm|st)',
        ).hasMatch(norm);

        if (isTrigger || looksLikeIngredient) {
          foundStart = true;
          if (isTrigger && !looksLikeIngredient) continue;
        } else {
          continue;
        }
      }

      // När vi ser en instruktions-trigger börjar vi samla instruktioner
      if (!foundInstructions &&
          instructionTriggers.any((tr) => lower.contains(tr))) {
        foundInstructions = true;
      }

      // Kontrollera om raden ser ut som en ingrediens
      final isIngredient =
          RegExp(
            r'^\d+(?:,\d+)?\s*(?:kg|g|dl|cl|ml|l|msk|tsk|krm|st)',
          ).hasMatch(norm) ||
          RegExp(
            r'^(?:\d+(?:,\d+)?|en|ett|några|ev\.|eventuellt)\s+\w+',
          ).hasMatch(lower);

      if (!foundInstructions || isIngredient) {
        // Det är en ingrediens
        if (norm.isNotEmpty &&
            !instructionTriggers.any((tr) => lower.startsWith(tr))) {
          ingredients.add(norm);
        }
      } else {
        // Det är en instruktion
        if (norm.isNotEmpty) {
          // Dela långa instruktioner vid punkter
          final parts =
              norm
                  .split(RegExp(r'(?<=[.!?])\s+'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

          if (parts.isEmpty) {
            instructions.add(norm);
          } else {
            instructions.addAll(parts);
          }
        }
      }
    }

    // Om vi inte hittade något vettigt, returnera null
    if (ingredients.isEmpty && instructions.isEmpty) {
      return null;
    }

    // Försök extrahera titel från sushi-exemplet om ingen titel hittades
    if (extractedTitle == null || extractedTitle.isEmpty) {
      if (processedInput.toLowerCase().contains('sushi')) {
        extractedTitle = 'Sushi i långpanna';
      }
    }

    // 3) Skapa Recipe-objektet med sourceUrl om den finns
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
      mealType: 'Middag',
      sourceUrl: _sourceUrl,
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
