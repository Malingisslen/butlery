// lib/views/photo_import_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/photo_import_viewmodel.dart';
import '../widgets/common/utility_components.dart';
import '../widgets/common/state_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.borderRadiusL)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Välj bildkälla', style: AppTextStyles.headlineSmall),
                const SizedBox(height: AppDimensions.spacingXl),

                // Kamera-alternativ
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.primary,
                    size: AppDimensions.iconSizeL,
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
                    size: AppDimensions.iconSizeL,
                  ),
                  title: const Text('Välj från galleri'),
                  subtitle: const Text('Välj en befintlig bild från telefonen'),
                  onTap: () {
                    Navigator.pop(context);
                    viewModel.pickImageFromGallery();
                  },
                ),

                const SizedBox(height: AppDimensions.spacingXl),
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
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Information om funktionen
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: AppColors.backgroundTint,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: AppDimensions.iconSizeM,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      'Ta bild av ett recept eller välj från galleriet för att importera text automatiskt',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),

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
            const SizedBox(height: AppDimensions.spacingXl),

            // Bildvisning
            _buildImagePreview(context, viewModel),
            const SizedBox(height: AppDimensions.spacingXl),

            // Error container
            if (viewModel.hasError) ...[
              StateWidget.error(
                message: viewModel.error!,
                onAction: () => viewModel.clearError(),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
            ],

            // OCR-resultat
            if (viewModel.hasOcrResult) ...[
              Text('Tolkad text:', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.spacingM),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                color: AppColors.backgroundTint,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(color: AppColors.divider),
              ),
                  child: SingleChildScrollView(
                    child: Text(
                      viewModel.ocrText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
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
        height: AppDimensions.imageHeightMedium,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withValues(alpha: 0.1),
              blurRadius: AppDimensions.elevationLow,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: StateWidget.loading(
          message: 'Bearbetar bild...',
        ),
      );
    }

    if (viewModel.hasImage) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withValues(alpha: 0.1),
              blurRadius: AppDimensions.elevationLow,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          child: Stack(
            children: [
              Image.memory(
                viewModel.imageBytes!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: AppDimensions.spacingS,
                right: AppDimensions.spacingS,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundBeige.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.neutralLight),
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
      height: AppDimensions.imageHeightMedium,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 2,
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
