// lib/views/photo_import_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/widgets/common/content_cards/image_preview_card.dart';
import 'package:butlery/widgets/common/buttons/overlay_button.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/injection.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.borderRadiusL)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Välj bildkälla', style: AppTextStyles.headlineSmall),
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
              width: double.infinity,
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
                  const SizedBox(width: AppDimensions.spacingS),
                  const Expanded(
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
              const Text('Tolkad text:', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.spacingM),
              Expanded(
                flex: 2,
                child: TextDisplayCard(
                  text: viewModel.ocrText,
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
      return ImagePreviewCard.loading(
        child: StateWidget.loading(
          message: 'Bearbetar bild...',
        ),
      );
    }

    if (viewModel.hasImage) {
      return ImagePreviewCard.loading(
        height: 300,
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
                child: OverlayButton.remove(
                  onPressed: viewModel.clearAll,
                  tooltip: 'Ta bort bild',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ImagePreviewCard.empty(
      context: context,
      child: StateWidget.empty(
        title: 'Ingen bild vald',
        subtitle: 'Tryck på knappen ovan för att välja',
        icon: Icons.add_photo_alternate,
      ),
    );
  }
}
