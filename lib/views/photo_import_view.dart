/// Photo import view for OCR-based recipe extraction from images.

// lib/views/photo_import_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/widgets/common/content_cards/image_preview_card.dart';
import 'package:butlery/widgets/common/buttons/overlay_button.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Photo import view with OCR processing for recipe extraction.
class PhotoImportView extends StatelessWidget {
  const PhotoImportView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<PhotoImportViewModel>(),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Välj bildkälla',
                  style: AppTextStyles.headlineSmall,
                ),
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

  /// Navigation escape route for OCR failures (Issue #029).
  void _navigateToManualEntry(
    BuildContext context,
    PhotoImportViewModel viewModel,
  ) {
    // Navigate even without OCR success - critical escape route
    Navigator.pushNamed(
      context,
      '/franSocialaMedier',
      arguments: viewModel.ocrText.isEmpty ? '' : viewModel.ocrText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PhotoImportViewModel>();

    return LayoutComponents.mainMenu(
      currentIndex: null,
      title: 'Importera från foto',
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: SingleChildScrollView(
              padding: AppDimensions.responsiveContentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Information om funktionen
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundTint,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusM,
                      ),
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

                  // Quality warning (Phase 2 Enhancement)
                  if (viewModel.hasImage &&
                      viewModel.qualityScore != null &&
                      viewModel.qualityScore! < 0.6 &&
                      !viewModel.hasError) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: AppDimensions.opacityVeryLight),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusM,
                        ),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: AppDimensions.opacityMediumLight),
                          width: AppDimensions.borderWidthStandard,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.warning,
                                size: AppDimensions.iconSizeM,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  'Bildkvaliteten är låg (${(viewModel.qualityScore! * 100).toInt()}%)',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: AppColors.onWarningContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (viewModel.recommendations != null &&
                              viewModel.recommendations!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              'Förbättringsförslag:',
                              style: AppTextStyles.badgeLarge.copyWith(
                                color: AppColors.onWarningContainer,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXs),
                            ...viewModel.recommendations!.map(
                              (rec) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimensions.spacingXxs,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.onWarningContainer,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        rec,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.onWarningContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDimensions.spacingSm),
                          Text(
                            'OCR kan misslyckas eller ge dåliga resultat.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onWarningContainer,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // Error container with recovery options
                  if (viewModel.hasError) ...[
                    StateWidget.error(
                      message: viewModel.error!,
                      onAction: viewModel.canRetryOcr
                          ? null // Don't show clear button when retry is available
                          : () => viewModel.clearError(),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Error recovery buttons (only shown when image is available)
                    if (viewModel.hasImage) ...[
                      // Retry OCR button
                      UtilityComponents.primaryButton(
                        context,
                        label: 'Försök igen',
                        icon: Icons.refresh,
                        onPressed: viewModel.isProcessing
                            ? null
                            : () => viewModel.retryOcr(),
                        isExpanded: true,
                      ),
                      const SizedBox(height: AppDimensions.spacingM),

                      // Continue without OCR button (escape route)
                      UtilityComponents.secondaryButton(
                        context,
                        label: 'Fortsätt utan OCR',
                        icon: Icons.edit,
                        onPressed: viewModel.isProcessing
                            ? null
                            : () => _navigateToManualEntry(context, viewModel),
                        isExpanded: true,
                      ),
                    ],

                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // OCR-resultat
                  if (viewModel.hasOcrResult) ...[
                    Row(
                      children: [
                        Text(
                          'Tolkad text:',
                          style: AppTextStyles.headlineSmall,
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        // Confidence indicator (Phase 2 Enhancement)
                        if (viewModel.confidence != null)
                          _buildConfidenceIndicator(
                            context,
                            viewModel.confidence!,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    TextDisplayCard(text: viewModel.ocrText),
                    const SizedBox(height: AppDimensions.spacingXl),
                    // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
                    UtilityComponents.primaryButton(
                      context,
                      label: 'Gå vidare till redigera',
                      icon: Icons.arrow_forward,
                      onPressed: () =>
                          _navigateToTextImport(context, viewModel),
                      isExpanded: true,
                    ),
                    // Add bottom padding for safe scrolling
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],
                ],
              ),
            ),
          ),
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
        child: StateWidget.loading(message: 'Bearbetar bild...'),
      );
    }

    if (viewModel.hasImage) {
      // Calculate adaptive height based on screen size (max 40% of screen height, min 200px)
      final screenHeight = MediaQuery.of(context).size.height;
      final adaptiveHeight = (screenHeight * 0.4).clamp(200.0, 400.0);

      return ImagePreviewCard.loading(
        height: adaptiveHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          child: Stack(
            children: [
              Image.memory(
                viewModel.imageBytes!,
                height: adaptiveHeight,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: AppDimensions.spacingS,
                right: AppDimensions.spacingS,
                child: OverlayButton.remove(
                  onPressed: viewModel.clearPhoto,
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

  /// Color-coded OCR confidence badge (green ≥80%, orange 60-79%, red <60%).
  Widget _buildConfidenceIndicator(BuildContext context, double confidence) {
    final percentage = (confidence * 100).toInt();
    Color badgeBackgroundColor;
    Color badgeBorderColor;
    Color badgeIconColor;
    Color badgeTextColor;
    IconData icon;
    String label;

    if (confidence >= 0.8) {
      // High confidence - Green
      badgeBackgroundColor = AppColors.success.withValues(alpha: AppDimensions.opacityVeryLight);
      badgeBorderColor = AppColors.success.withValues(alpha: AppDimensions.opacityMediumLight);
      badgeIconColor = AppColors.success;
      badgeTextColor = AppColors.onSuccessContainer;
      icon = Icons.check_circle;
      label = 'Hög kvalitet';
    } else if (confidence >= 0.6) {
      // Medium confidence - Orange
      badgeBackgroundColor = AppColors.warning.withValues(alpha: AppDimensions.opacityVeryLight);
      badgeBorderColor = AppColors.warning.withValues(alpha: AppDimensions.opacityMediumLight);
      badgeIconColor = AppColors.warning;
      badgeTextColor = AppColors.onWarningContainer;
      icon = Icons.info;
      label = 'God kvalitet';
    } else {
      // Low confidence - Red
      badgeBackgroundColor = AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight);
      badgeBorderColor = AppColors.error.withValues(alpha: AppDimensions.opacityMediumLight);
      badgeIconColor = AppColors.error;
      badgeTextColor = AppColors.onErrorContainer;
      icon = Icons.warning;
      label = 'Låg kvalitet';
    }

    return Tooltip(
      message: '$label: $percentage% säkerhet',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: badgeBackgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          border: Border.all(
            color: badgeBorderColor,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppDimensions.iconSizeS, color: badgeIconColor),
            const SizedBox(width: AppDimensions.spacingXxs),
            Text(
              '$percentage%',
              style: AppTextStyles.badgeLarge.copyWith(
                color: badgeTextColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources    super.dispose();
  }
}
