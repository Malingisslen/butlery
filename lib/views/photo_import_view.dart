// lib/views/photo_import_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/photo_import_viewmodel.dart';
import '../widgets/common/utility_components.dart';
import '../widgets/common/state_widget.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ MIGRERAD FOTO-OCR VY - Nu med UtilityComponents
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

  void _showImageSourceDialog(BuildContext context) {
    final viewModel = context.read<PhotoImportViewModel>();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppTheme.largeRadius.topLeft),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: AppTheme.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Välj bildkälla', style: AppTheme.sectionTitleStyle),
                AppTheme.mediumGap,

                // Kamera-alternativ
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.primary,
                    size: AppTheme.iconSizeNavigation,
                  ),
                  title: const Text('Ta ett foto'),
                  subtitle: const Text('Använd kameran för att fota receptet'),
                  onTap: () {
                    Navigator.pop(context);
                    viewModel.pickImageFromCamera();
                  },
                ),

                // Galleri-alternativ
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).colorScheme.primary,
                    size: AppTheme.iconSizeNavigation,
                  ),
                  title: const Text('Välj från galleri'),
                  subtitle: const Text('Välj en befintlig bild från telefonen'),
                  onTap: () {
                    Navigator.pop(context);
                    viewModel.pickImageFromGallery();
                  },
                ),

                AppTheme.mediumGap,
              ],
            ),
          ),
        );
      },
    );
  }

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
      appBar: AppBar(title: const Text('Importera från foto')),
      body: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Information om funktionen
            Container(
              padding: AppTheme.cardPadding,
              decoration: AppTheme.infoBoxDecoration(context),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: AppTheme.iconSizeInfo,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Ta bild av ett recept eller välj från galleriet för att importera text automatiskt',
                      style: AppTheme.captionStyle,
                    ),
                  ),
                ],
              ),
            ),
            AppTheme.mediumGap,

            // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
            UtilityComponents.primaryButton(
              context,
              label: viewModel.hasImage ? 'Välj ny bild' : 'Välj bild',
              icon: Icons.add_photo_alternate,
              onPressed: viewModel.isProcessing
                  ? null
                  : () => _showImageSourceDialog(context),
              isExpanded: true,
            ),
            AppTheme.mediumGap,

            // Bildvisning
            _buildImagePreview(context, viewModel),
            AppTheme.mediumGap,

            // Error container
            if (viewModel.hasError) ...[
              StateWidget.error(
                message: viewModel.error!,
                onAction: () => viewModel.clearError(),
              ),
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
                  decoration: AppTheme.infoBoxDecoration(context),
                  child: SingleChildScrollView(
                    child: Text(
                      viewModel.ocrText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              AppTheme.mediumGap,
              // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
              UtilityComponents.primaryButton(
                context,
                label: 'Gå vidare till redigera',
                icon: Icons.arrow_forward,
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
        decoration: AppTheme.cardDecoration,
        child: StateWidget.loading(
          message: 'Bearbetar bild...',
        ),
      );
    }

    if (viewModel.hasImage) {
      return Container(
        height: AppTheme.imageHeightLarge,
        decoration: BoxDecoration(
          borderRadius: AppTheme.largeRadius,
          boxShadow: AppTheme.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: AppTheme.largeRadius,
          child: Stack(
            children: [
              Image.memory(
                viewModel.imageBytes!,
                height: AppTheme.imageHeightLarge,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: AppTheme.spacingSm,
                right: AppTheme.spacingSm,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.overlay,
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.neutralLight),
                    onPressed: viewModel.clearAll,
                    tooltip: 'Ta bort bild',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: AppTheme.imageHeightMedium,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: AppTheme.strokeWidth2,
          style: BorderStyle.solid,
        ),
      ),
      child: StateWidget.empty(
        title: 'Ingen bild vald',
        subtitle: 'Tryck på knappen ovan för att välja',
        icon: Icons.add_photo_alternate,
      ),
    );
  }
}
