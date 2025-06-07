// lib/views/fran_sociala_medier_view.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../views/skriv_sjalv_recept_view.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';

/// ✨ UPPDATERAD VY FÖR SOCIAL MEDIA IMPORT MED RECIPESERVICE
/// Tar emot initialText om du vill förifylla från t.ex. OCR eller URL-import.
class FranSocialaMedierView extends StatefulWidget {
  final String? initialText;

  const FranSocialaMedierView({super.key, this.initialText});

  @override
  State<FranSocialaMedierView> createState() => _FranSocialaMedierViewState();
}

class _FranSocialaMedierViewState extends State<FranSocialaMedierView> {
  late final TextEditingController _textController;
  bool _isParsing = false;

  @override
  void initState() {
    super.initState();

    // 1) Förifyll textfältet om initialText finns
    _textController = TextEditingController(text: widget.initialText ?? '');

    // 2) Om initialText finns, kör parsern automatiskt så snart vyn är uppbyggd
    if ((widget.initialText ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _parseAndNavigate();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parseAndNavigate() async {
    final input = _textController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ange text att tolka')));
      return;
    }

    setState(() {
      _isParsing = true;
    });

    try {
      // Simulera parsing-tid för bättre UX
      await Future.delayed(const Duration(milliseconds: 300));

      final parsedRecipe = _parseTextToRecipe(input);

      if (!mounted) return;

      // Navigera till redigera-vyn med det parsade receptet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SkrivSjalvReceptView(initialRecipe: parsedRecipe),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kunde inte tolka text: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    }
  }

  /// Parsar text till Recipe-objekt (förbättrad logik)
  Recipe _parseTextToRecipe(String input) {
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

    // 3) Skapa Recipe-objektet
    return Recipe(
      id: const Uuid().v4(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Klistra in recepttext')),
      body: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          children: [
            // Instruktionstext
            Container(
              width: double.infinity,
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppTheme.mediumRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: AppTheme.iconSizeInfo,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: AppTheme.spacingSm),
                      Text(
                        'Tips för bästa resultat',
                        style: AppTheme.formLabelStyle.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  AppTheme.smallGap,
                  Text(
                    '• Klistra in hela receptet inklusive ingredienser\n'
                    '• Se till att ingredienser kommer före instruktioner\n'
                    '• Texten kan komma från Instagram, TikTok, Facebook etc.',
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ),
            AppTheme.mediumGap,

            // Textfält för input
            Expanded(
              child: TextFormField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText:
                      'Klistra in recepttext här...\n\n'
                      'Exempel:\n'
                      'Köttfärssås\n'
                      '500g köttfärs\n'
                      '1 gul lök\n'
                      '1 burk krossade tomater\n\n'
                      'Gör så här:\n'
                      '1. Stek löken\n'
                      '2. Tillsätt färs och stek\n'
                      '3. Häll i tomaterna och låt sjuda',
                  hintStyle: AppTheme.inputHintStyle,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            AppTheme.mediumGap,

            // Parse-knapp
            ActionButton.primary(
              label: 'Förhandsgranska och redigera',
              icon: Icons.preview,
              onPressed: _isParsing ? null : _parseAndNavigate,
              isLoading: _isParsing,
              loadingText: 'Tolkar text...',
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
