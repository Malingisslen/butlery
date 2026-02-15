/// FAQ view displaying common questions and answers for Butlery users.

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Simple FAQ page with Swedish Q&A content in expandable tiles.
class FaqView extends StatelessWidget {
  const FaqView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vanliga fragor',
          style: AppTextStyles.headerTitle.copyWith(
            color: cs.onPrimary,
          ),
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      backgroundColor: cs.surfaceContainerHighest,
      body: ListView(
        padding: AppDimensions.screenPadding,
        children: const [
          _FaqTile(
            question: 'Hur importerar jag recept?',
            answer: 'Du kan importera recept pa flera satt: '
                'klistra in en URL fran en receptsida, '
                'ta ett foto av ett recept, '
                'eller klistra in recepttext direkt. '
                'Tryck pa "Lagg till" pa startsidan och valj metod.',
          ),
          _FaqTile(
            question: 'Hur delar jag recept med vanner?',
            answer: 'Oppna ett recept och tryck pa dela-ikonen. '
                'Du kan skicka receptet till vanner som anvander Butlery, '
                'eller dela en lank. Dina vanner kan sedan spara '
                'receptet till sin egen samling.',
          ),
          _FaqTile(
            question: 'Hur anvander jag veckomeny?',
            answer: 'Ga till veckomeny via navigeringen. '
                'Dar kan du planera veckans maltider genom att '
                'lagga till recept fran din samling. '
                'Ingredienser fran menyn kan skickas direkt till inkopslistan.',
          ),
          _FaqTile(
            question: 'Hur skapar jag personliga taggar?',
            answer: 'Ga till profilen och valj "Mina taggar". '
                'Dar kan du skapa taggar som "Vardagsmat" eller "Festmat" '
                'och tilldela dem till dina recept for enkel filtrering.',
          ),
          _FaqTile(
            question: 'Hur rapporterar jag problem?',
            answer: 'Tryck pa "!"-knappen som syns langst ner till hoger '
                'pa varje sida. Dar kan du beskriva problemet, '
                'valja kategori och bifoga en skarmavbild. '
                'Vi laser all feedback!',
          ),
        ],
      ),
    );
  }
}

/// Single expandable FAQ tile.
class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      title: Text(
        question,
        style: AppTextStyles.titleMedium.copyWith(
          color: cs.onSurface,
        ),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(
        bottom: AppDimensions.spacingMd,
      ),
      shape: Border(
        bottom: BorderSide(
          color: cs.outlineVariant,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
