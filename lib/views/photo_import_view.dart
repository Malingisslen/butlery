// lib/views/photo_import_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/photo_import_viewmodel.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD FOTO-OCR VY MED PHOTOIMPORTVIEWMODEL
class PhotoImportView extends StatelessWidget {
  const PhotoImportView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<PhotoImportViewModel>(),
      child: const _PhotoImportViewContent(),
    );
  }
}

class _PhotoImportViewContent extends StatelessWidget {
  const _PhotoImportViewContent();

  void _navigateToTextImport(
    BuildContext context,
    PhotoImportViewModel viewModel,
  ) {
    if (viewModel.hasOcrResult) {
      Navigator.pushNamed(
        context,
        '/franSocialaMedier',
        arguments: viewModel.ocrText,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PhotoImportViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Foto-OCR')),
      body: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ta bild-knapp
            ActionButton.primary(
              label: 'Ta bild & tolka',
              icon: Icons.camera_alt,
              onPressed:
                  viewModel.isProcessing ? null : viewModel.pickImageAndProcess,
              isExpanded: true,
            ),
            AppTheme.mediumGap,

            // Bildvisning
            _buildImagePreview(context, viewModel),
            AppTheme.mediumGap,

            // Error container
            if (viewModel.hasError) ...[
              AppTheme.errorContainer(context, viewModel.error!),
              AppTheme.mediumGap,
            ],

            // OCR-resultat
            if (viewModel.hasOcrResult) ...[
              Text('Tolkad text:', style: AppTheme.sectionTitleStyle),
              AppTheme.smallGap,
              Expanded(
                flex: 2,
                child: Container(
                  padding: AppTheme.cardPadding,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      viewModel.ocrText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              AppTheme.mediumGap,
              ActionButton.primary(
                label: 'Gå vidare till redigera',
                onPressed: () => _navigateToTextImport(context, viewModel),
                isExpanded: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(
    BuildContext context,
    PhotoImportViewModel viewModel,
  ) {
    if (viewModel.isProcessing) {
      return Container(
        height: AppTheme.imageHeightMedium,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppTheme.mediumRadius,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTheme.mediumLoadingIndicator(),
              AppTheme.smallGap,
              Text('Bearbetar bild...', style: AppTheme.subtitleStyle),
            ],
          ),
        ),
      );
    }

    if (viewModel.hasImage) {
      return ClipRRect(
        borderRadius: AppTheme.mediumRadius,
        child: Image.memory(
          viewModel.imageBytes!,
          height: AppTheme.imageHeightMedium,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      height: AppTheme.imageHeightMedium,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: AppTheme.iconSizeHero,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            AppTheme.smallGap,
            Text('Ingen bild vald', style: AppTheme.subtitleStyle),
          ],
        ),
      ),
    );
  }
}
