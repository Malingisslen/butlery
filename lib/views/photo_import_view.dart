/// Photo import view for OCR-based recipe extraction from images.

// lib/views/photo_import_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Photo import view with OCR processing for recipe extraction.
class PhotoImportView extends StatefulWidget {
  const PhotoImportView({super.key});

  @override
  State<PhotoImportView> createState() => _PhotoImportViewState();
}

class _PhotoImportViewState extends State<PhotoImportView> {
  late final PhotoImportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<PhotoImportViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
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
                  context.l10n.importChooseImageSource,
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
                  title: Text(context.l10n.importTakePhoto),
                  subtitle: Text(context.l10n.importTakePhotoSubtitle),
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
                  title: Text(context.l10n.importChooseFromGallery),
                  subtitle: Text(context.l10n.importChooseFromGallerySubtitle),
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
    final cs = Theme.of(context).colorScheme;
    final viewModel = context.watch<PhotoImportViewModel>();

    return LayoutComponents.mainMenu(
      currentIndex: null,
      title: context.l10n.importFromPhoto,
      body: SafeArea(
        // RESPONSIVE: Center and constrain content on large screens
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
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusM,
                      ),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: AppDimensions.iconSizeM,
                          color: cs.primary,
                        ),
                        const SizedBox(width: AppDimensions.spacingS),
                        Expanded(
                          child: Text(
                            context.l10n.importPhotoDescription,
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),

                  UtilityComponents.primaryButton(
                    context,
                    label: viewModel.hasImage
                        ? context.l10n.importChooseNewImage
                        : context.l10n.importChooseImage,
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

                  // BUT-410: heirloom toggle + form, only when an image exists.
                  // Kept between the preview and OCR-quality warnings so the
                  // user sees it as a property of the chosen photo.
                  if (viewModel.hasImage) ...[
                    _HeirloomSection(viewModel: viewModel),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // Quality warning (Phase 2 Enhancement)
                  if (viewModel.hasImage &&
                      viewModel.qualityScore != null &&
                      viewModel.qualityScore! < 0.6 &&
                      !viewModel.hasError) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      decoration: BoxDecoration(
                        color: context.butleryColors.warning
                            .withValues(alpha: AppDimensions.opacityVeryLight),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusM,
                        ),
                        border: Border.all(
                          color: context.butleryColors.warning.withValues(
                              alpha: AppDimensions.opacityMediumLight),
                          width: AppDimensions.borderWidthStandard,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: context.butleryColors.warning,
                                size: AppDimensions.iconSizeM,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  context.l10n.importImageQualityLow(
                                      (viewModel.qualityScore! * 100).toInt()),
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: context
                                        .butleryColors.onWarningContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (viewModel.recommendations != null &&
                              viewModel.recommendations!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              context.l10n.importImprovementSuggestions,
                              style: AppTextStyles.badgeLarge.copyWith(
                                color: context.butleryColors.onWarningContainer,
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
                                        color: context
                                            .butleryColors.onWarningContainer,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        rec,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: context
                                              .butleryColors.onWarningContainer,
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
                            context.l10n.importOcrMayFail,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.butleryColors.onWarningContainer,
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
                        label: context.l10n.commonRetry,
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
                        label: context.l10n.importContinueWithoutOcr,
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
                          context.l10n.importInterpretedText,
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
                    UtilityComponents.primaryButton(
                      context,
                      label: context.l10n.importProceedToEdit,
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
        context: context,
        child: StateWidget.loading(message: context.l10n.importProcessingImage),
      );
    }

    if (viewModel.hasImage) {
      // Calculate adaptive height based on screen size (max 40% of screen height, min 200px)
      final screenHeight = MediaQuery.of(context).size.height;
      final adaptiveHeight = (screenHeight * 0.4).clamp(200.0, 400.0);

      return ImagePreviewCard.loading(
        context: context,
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
                  tooltip: context.l10n.importRemoveImage,
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
        title: context.l10n.importNoImageSelected,
        subtitle: context.l10n.importTapButtonToSelect,
        icon: Icons.add_photo_alternate,
      ),
    );
  }

  /// Color-coded OCR confidence badge (green >=80%, orange 60-79%, red <60%).
  Widget _buildConfidenceIndicator(BuildContext context, double confidence) {
    final cs = Theme.of(context).colorScheme;
    final percentage = (confidence * 100).toInt();
    Color badgeBackgroundColor;
    Color badgeBorderColor;
    Color badgeIconColor;
    Color badgeTextColor;
    IconData icon;
    String label;

    if (confidence >= 0.8) {
      // High confidence - Green
      badgeBackgroundColor = context.butleryColors.success
          .withValues(alpha: AppDimensions.opacityVeryLight);
      badgeBorderColor = context.butleryColors.success
          .withValues(alpha: AppDimensions.opacityMediumLight);
      badgeIconColor = context.butleryColors.success;
      badgeTextColor = context.butleryColors.onSuccessContainer;
      icon = Icons.check_circle;
      label = context.l10n.importHighQuality;
    } else if (confidence >= 0.6) {
      // Medium confidence - Orange
      badgeBackgroundColor = context.butleryColors.warning
          .withValues(alpha: AppDimensions.opacityVeryLight);
      badgeBorderColor = context.butleryColors.warning
          .withValues(alpha: AppDimensions.opacityMediumLight);
      badgeIconColor = context.butleryColors.warning;
      badgeTextColor = context.butleryColors.onWarningContainer;
      icon = Icons.info;
      label = context.l10n.importGoodQuality;
    } else {
      // Low confidence - Red
      badgeBackgroundColor =
          cs.error.withValues(alpha: AppDimensions.opacityVeryLight);
      badgeBorderColor =
          cs.error.withValues(alpha: AppDimensions.opacityMediumLight);
      badgeIconColor = cs.error;
      badgeTextColor = cs.onErrorContainer;
      icon = Icons.warning;
      label = context.l10n.importLowQuality;
    }

    return Tooltip(
      message: context.l10n.importConfidenceTooltip(label, percentage),
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

/// BUT-410 heirloom toggle + metadata form.
///
/// Visible whenever an image is loaded. Toggle on → reveals three form
/// fields (writer / year / note) bound directly to [PhotoImportViewModel]'s
/// heirloom state. Shows an offline banner when [PhotoImportViewModel.isOfflineQueued]
/// is set after a failed upload attempt.
class _HeirloomSection extends StatefulWidget {
  final PhotoImportViewModel viewModel;

  const _HeirloomSection({required this.viewModel});

  @override
  State<_HeirloomSection> createState() => _HeirloomSectionState();
}

class _HeirloomSectionState extends State<_HeirloomSection> {
  late final TextEditingController _writerCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _writerCtrl =
        TextEditingController(text: widget.viewModel.heirloomWriterName);
    _yearCtrl = TextEditingController(
      text: widget.viewModel.heirloomYear?.toString() ?? '',
    );
    _noteCtrl = TextEditingController(text: widget.viewModel.heirloomNote);
  }

  @override
  void dispose() {
    _writerCtrl.dispose();
    _yearCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = widget.viewModel;
    final currentYear = DateTime.now().year;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.l10n.heirloomToggle,
              style: AppTextStyles.titleSmall,
            ),
            value: vm.isHeirloom,
            onChanged: (v) => vm.isHeirloom = v,
          ),
          if (vm.isHeirloom) ...[
            const SizedBox(height: AppDimensions.spacingS),
            if (vm.isOfflineQueued)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: context.butleryColors.warning
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  border: Border.all(
                    color: context.butleryColors.warning
                        .withValues(alpha: AppDimensions.opacityMediumLight),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off,
                        color: context.butleryColors.warning,
                        size: AppDimensions.iconSizeM),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        context.l10n.heirloomUploadOffline,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.butleryColors.onWarningContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _writerCtrl,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: context.l10n.heirloomWriterLabel,
              ),
              onChanged: (v) => vm.heirloomWriterName = v,
            ),
            const SizedBox(height: AppDimensions.spacingS),
            TextField(
              controller: _yearCtrl,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: context.l10n.heirloomYearLabel,
              ),
              onChanged: (v) {
                // Silently clear out-of-range — HeirloomMetadata's ctor
                // would throw otherwise, and we don't want to block typing.
                final parsed = int.tryParse(v);
                vm.heirloomYear =
                    (parsed == null || parsed < 1800 || parsed > currentYear)
                        ? null
                        : parsed;
              },
            ),
            const SizedBox(height: AppDimensions.spacingS),
            TextField(
              controller: _noteCtrl,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.heirloomNoteLabel,
              ),
              onChanged: (v) => vm.heirloomNote = v,
            ),
          ],
        ],
      ),
    );
  }
}
