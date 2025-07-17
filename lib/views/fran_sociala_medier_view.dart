// lib/views/fran_sociala_medier_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/text_import_viewmodel.dart';
import '../views/skriv_sjalv_recept_view.dart';
import '../widgets/common/utility_components.dart';
import '../widgets/common/state_widget.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ MIGRERAD VY MED SOURCEURL-STÖD - Nu med UtilityComponents
class FranSocialaMedierView extends StatelessWidget {
  final String? initialText;
  final String? sourceUrl;

  const FranSocialaMedierView({
    super.key,
    this.initialText,
    this.sourceUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final viewModel = sl<TextImportViewModel>();

        // Sätt sourceUrl om den finns
        if (sourceUrl != null) {
          viewModel.setSourceUrl(sourceUrl!);
        }

        // Om vi har initial text, sätt den direkt
        if (initialText != null && initialText!.isNotEmpty) {
          viewModel.updateInputText(initialText!);
          // Parse automatiskt efter att widgeten byggts
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel.parseText().then((success) {
              if (success && context.mounted) {
                Navigator.pushNamed(
                  context,
                  '/skrivSjalv',
                  arguments: {
                    'initialRecipe': viewModel.parsedRecipe,
                    'isTemplate': true,
                  },
                );
              }
            });
          });
        }
        return viewModel;
      },
      child: const _FranSocialaMedierViewContent(),
    );
  }
}

class _FranSocialaMedierViewContent extends StatelessWidget {
  const _FranSocialaMedierViewContent();

  void _parseAndNavigate(BuildContext context) async {
    final viewModel = context.read<TextImportViewModel>();
    final success = await viewModel.parseText();

    if (success && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SkrivSjalvReceptView(
            initialRecipe: viewModel.parsedRecipe,
            isTemplate: true,
          ),
        ),
      );
    } else if (context.mounted && viewModel.hasError) {
      // ✅ MIGRERAD: Använd UtilityComponents.showErrorSnackbar
      UtilityComponents.showErrorSnackbar(context, viewModel.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TextImportViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Klistra in recepttext')),
      body: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          children: [
            // Instruktionstext
            _buildInstructions(context),
            AppTheme.mediumGap,

            // Visa om receptet kommer från URL
            if (viewModel.sourceUrl != null) ...[
              Container(
                width: double.infinity,
                padding: AppTheme.cardPadding,
                decoration: AppTheme.infoBoxDecoration(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: AppTheme.iconSizeInfo,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        'Importerat från: ${viewModel.sourceUrl}',
                        style: AppTheme.captionStyle.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              AppTheme.smallGap,
            ],

            // Textfält för input
            Expanded(
              child: TextFormField(
                initialValue: viewModel.inputText,
                onChanged: viewModel.updateInputText,
                enabled: !viewModel.isParsing,
                decoration: InputDecoration(
                  hintText: 'Klistra in recepttext här...\n\n'
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
                  suffixIcon: viewModel.inputText.isNotEmpty
                      ? IconButton(
                          icon: AppTheme.actionIcon(context, Icons.clear),
                          onPressed: viewModel.clearInput,
                        )
                      : null,
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

            // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
            UtilityComponents.primaryButton(
              context,
              label: 'Förhandsgranska och redigera',
              icon: Icons.preview,
              onPressed: viewModel.isParsing || !viewModel.canParse
                  ? null
                  : () => _parseAndNavigate(context),
              isLoading: viewModel.isParsing,
              loadingText: 'Tolkar text...',
              isExpanded: true,
            ),

            // Error message
            if (viewModel.hasError) ...[
              AppTheme.smallGap,
              StateWidget.error(
                message: viewModel.error!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppTheme.cardPadding,
      decoration: AppTheme.infoBoxDecoration(context),
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
    );
  }
}
