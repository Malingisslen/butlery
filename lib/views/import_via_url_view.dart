// lib/views/import_via_url_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// ✨ UPPDATERAD IMPORT VIA URL VY MED SOURCEURL-STÖD
class ImportViaUrlView extends StatelessWidget {
  const ImportViaUrlView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<UrlImportViewModel>(),
      child: const _ImportViaUrlViewContent(),
    );
  }
}

class _ImportViaUrlViewContent extends StatefulWidget {
  const _ImportViaUrlViewContent();

  @override
  State<_ImportViaUrlViewContent> createState() =>
      _ImportViaUrlViewContentState();
}

class _ImportViaUrlViewContentState extends State<_ImportViaUrlViewContent> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _extractedTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _extractedTextController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final viewModel = context.read<UrlImportViewModel>();
    viewModel.updateUrl(_urlController.text);
  }

  void _fetchPage() {
    final viewModel = context.read<UrlImportViewModel>();
    viewModel.fetchFromUrl();
  }

  void _navigateToTextImport() {
    final viewModel = context.read<UrlImportViewModel>();
    if (viewModel.hasExtractedText) {
      // Use edited text from controller instead of original extracted text
      final editedText = _extractedTextController.text.trim();
      if (editedText.isNotEmpty) {
        Navigator.pushNamed(
          context,
          '/franSocialaMedier',
          arguments: {
            'text': editedText,
            'sourceUrl': viewModel.sourceUrl,
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UrlImportViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Import via URL')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.paddingL,
            AppDimensions.paddingL, 
            AppDimensions.paddingL,
            AppDimensions.paddingL + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            children: [
            // URL input
            TextFormField(
              controller: _urlController,
              enabled: !viewModel.isLoading,
              decoration: const InputDecoration(
                labelText: 'Klistra in recept-URL',
                border: OutlineInputBorder(),
                hintText: 'https://example.com/recept',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _fetchPage(),
            ),
            const SizedBox(height: AppDimensions.spacingXl),

            // Hämta-knapp
            ElevatedButton(
              onPressed:
                  viewModel.canFetch && !viewModel.isLoading
                      ? _fetchPage
                      : null,
              style: ComponentThemes.primaryButtonStyle,
              child:
                  viewModel.isLoading
                      ? const SizedBox(
                          width: AppDimensions.iconSizeS,
                          height: AppDimensions.iconSizeS,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.cardWhite),
                          ),
                        )
                      : const Text('Hämta text'),
            ),

            // Error visning
            if (viewModel.hasError) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              StateWidget.error(
                message: viewModel.error!,
              ),
            ],

            // Extraherad text (editable)
            if (viewModel.hasExtractedText) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              const Text('Extraherad text:', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.spacingS),
              Expanded(
                child: TextFormField(
                  controller: _extractedTextController..text = viewModel.extractedText,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Redigera text innan import',
                    hintText: 'Du kan redigera den extraherade texten här...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              ElevatedButton(
                onPressed: _navigateToTextImport,
                style: ComponentThemes.primaryButtonStyle,
                child: const Text('Gå vidare till klistra-in'),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
