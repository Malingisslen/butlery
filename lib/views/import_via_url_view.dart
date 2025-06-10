// lib/views/import_via_url_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/url_import_viewmodel.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD IMPORT VIA URL VY MED URLIMPORTVIEWMODEL
class ImportViaUrlView extends StatelessWidget {
  const ImportViaUrlView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<UrlImportViewModel>(),
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

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
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
      Navigator.pushNamed(
        context,
        '/franSocialaMedier',
        arguments: viewModel.extractedText,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UrlImportViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Import via URL')),
      body: Padding(
        padding: AppTheme.screenPadding,
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
            AppTheme.mediumGap,

            // Hämta-knapp
            ElevatedButton(
              onPressed:
                  viewModel.canFetch && !viewModel.isLoading
                      ? _fetchPage
                      : null,
              style: AppTheme.primaryButtonStyle,
              child:
                  viewModel.isLoading
                      ? AppTheme.smallLoadingIndicator(context)
                      : const Text('Hämta text'),
            ),

            // Error visning
            if (viewModel.hasError) ...[
              AppTheme.mediumGap,
              AppTheme.errorContainer(context, viewModel.error!),
            ],

            // Extraherad text
            if (viewModel.hasExtractedText) ...[
              AppTheme.mediumGap,
              Text('Extraherad text:', style: AppTheme.sectionTitleStyle),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: AppTheme.cardPadding,
                    margin: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: AppTheme.mediumRadius,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      viewModel.extractedText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              AppTheme.mediumGap,
              ElevatedButton(
                onPressed: _navigateToTextImport,
                style: AppTheme.primaryButtonStyle,
                child: const Text('Gå vidare till klistra-in'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
