/// Comprehensive photo import view providing intelligent OCR processing and recipe extraction for Flutter applications.
///
/// This module implements sophisticated photo-based recipe import following Single Responsibility Principle,
/// specializing in image capture, OCR processing, text extraction, and comprehensive photo import workflow coordination.
/// It provides complete photo import interface while maintaining clean separation from business logic,
/// data persistence, and state management through PhotoImportViewModel integration and modern component architecture.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles photo import UI presentation concerns through intelligent image processing:
/// - **Image Capture Excellence**: Advanced image acquisition with camera and gallery integration
/// - **OCR Processing Intelligence**: Sophisticated optical character recognition with multi-engine support
/// - **Text Extraction Coordination**: Comprehensive text extraction with recipe recognition and validation
/// - **Import Workflow Management**: Advanced workflow coordination with automatic text routing and processing
/// - **Swedish Localization Excellence**: Complete Swedish language support for photo import operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - OCR processing algorithms and text extraction logic (handled by PhotoImportViewModel and OCR services)
/// - Image processing and optimization (handled by image processing services and optimization infrastructure)
/// - Text parsing and recipe extraction (handled by text import ViewModels and parsing services)
/// - Camera and gallery access implementation (handled by image picker services and platform integration)
///
/// **Photo Import View Architecture:**
/// - **Multi-Source Image Capture**: Advanced image acquisition with camera and gallery options
/// - **Intelligent OCR Processing**: Sophisticated text extraction with multi-engine OCR coordination
/// - **Adaptive Workflow Routing**: Dynamic navigation based on OCR success and text quality
/// - **Error Recovery System**: Comprehensive error handling with retry options and user guidance
/// - **Preview and Validation**: Advanced image preview with text extraction validation and editing options
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to photo import view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => PhotoImportView(),
///   ),
/// );
/// 
/// // The view provides comprehensive photo import functionality:
/// // - Multi-source image capture with camera and gallery integration
/// // - Intelligent OCR processing with automatic text extraction
/// // - Image preview with text validation and editing options
/// // - Automatic routing to text import upon successful extraction
/// // - Error handling with retry options and user guidance
/// 
/// // Processing workflow examples:
/// // - Camera capture: Real-time photo taking with OCR processing
/// // - Gallery selection: Image selection with automatic OCR analysis
/// // - Text extraction: Multi-engine OCR with quality validation
/// // - Recipe routing: Automatic navigation to text editing workflow
/// ```

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
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive photo import view providing intelligent OCR processing and recipe extraction through advanced image analysis.
///
/// Manages complete photo-based import interface enabling image capture, OCR processing, text extraction,
/// and comprehensive import workflow while maintaining clean separation between UI presentation
/// and business logic through PhotoImportViewModel integration and specialized component architecture.
///
/// **Core Responsibilities:**
/// - Advanced image capture with multi-source acquisition including camera and gallery integration
/// - OCR processing coordination with intelligent text extraction, validation, and quality assessment
/// - Import workflow management with automatic navigation, text routing, and comprehensive processing coordination
/// - Preview and validation handling with image display, text extraction preview, and editing workflow integration
/// - Swedish localized import experience with comprehensive user feedback and instructional guidance
class PhotoImportView extends StatelessWidget {
  /// Creates comprehensive photo import view with OCR processing and workflow coordination.
  /// 
  /// Establishes photo import interface with intelligent image processing,
  /// OCR coordination, and comprehensive import functionality through
  /// PhotoImportViewModel integration and automatic workflow management.
  const PhotoImportView({super.key});

  /// Comprehensive photo import interface construction with ViewModel integration and OCR processing coordination.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete photo import interface featuring image capture, OCR processing,
  /// and comprehensive import workflow through PhotoImportViewModel integration
  /// with service locator dependency injection and specialized content coordination.
  /// 
  /// **Interface Architecture:**
  /// - PhotoImportViewModel integration with service locator and dependency injection
  /// - OCR processing coordination with multi-engine support and validation
  /// - Image capture workflow with camera and gallery integration
  /// - Content presentation with preview functionality and text extraction display
  /// 
  /// Returns complete photo import interface with comprehensive functionality and OCR processing.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<PhotoImportViewModel>(),
      child: const _PhotoImportViewContent(),
    );
  }
}

/// Photo import view content managing image capture, OCR processing, and comprehensive workflow coordination.
///
/// Handles complete photo import state management including image selection, OCR processing, text extraction,
/// and workflow navigation while maintaining clean PhotoImportViewModel integration and proper lifecycle management
/// through comprehensive import workflow coordination and user experience optimization.
class _PhotoImportViewContent extends StatelessWidget {
  /// Creates photo import view content with image processing and OCR coordination.
  /// 
  /// Establishes stateless content interface enabling image capture, OCR processing,
  /// and comprehensive import functionality through proper ViewModel integration
  /// and workflow coordination with user experience optimization.
  const _PhotoImportViewContent();

  /// Image source selection dialog with camera and gallery options coordination.
  /// 
  /// Displays image source selection enabling camera capture and gallery selection
  /// through modal bottom sheet presentation with PhotoImportViewModel integration
  /// and comprehensive source option coordination.
  /// 
  /// [context] Build context for dialog presentation and ViewModel access
  /// 
  /// **Source Selection Features:**
  /// - Modal bottom sheet with responsive design and proper visual hierarchy
  /// - Camera option with real-time photo capture and automatic OCR processing
  /// - Gallery option with image selection and OCR analysis coordination
  /// - User guidance with descriptive subtitles and icon coordination
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

  /// Text import navigation with OCR result coordination and workflow routing.
  /// 
  /// Navigates to text import enabling OCR result processing, recipe editing,
  /// and comprehensive text import functionality through proper routing
  /// with extracted text coordination and workflow management.
  /// 
  /// [context] Build context for navigation and route coordination
  /// [viewModel] PhotoImportViewModel for OCR result access and state management
  /// 
  /// **Navigation Features:**
  /// - OCR result validation with text availability checking
  /// - Route navigation with text import integration and processing coordination
  /// - Extracted text passing with proper argument coordination
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

  /// Comprehensive photo import interface construction with OCR processing and workflow coordination.
  /// 
  /// [context] Build context for theme access and ViewModel integration
  /// 
  /// Constructs complete photo import interface featuring image capture, OCR processing,
  /// text extraction display, and comprehensive user experience through PhotoImportViewModel
  /// integration with real-time processing feedback and workflow coordination.
  /// 
  /// **Interface Architecture:**
  /// - Instructional guidance with OCR feature explanation and user education
  /// - Image selection controls with multi-source capture and processing coordination
  /// - Image preview with processing states and visual feedback
  /// - OCR results display with extracted text preview and editing navigation
  /// - Error handling with user feedback and recovery options
  /// 
  /// Returns complete photo import interface with comprehensive functionality and OCR processing.
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

  /// Image preview construction with processing states and interaction coordination.
  /// 
  /// [context] Build context for theme access and component construction
  /// [viewModel] PhotoImportViewModel for image state and processing coordination
  /// 
  /// Constructs image preview enabling processing state display, image presentation,
  /// and comprehensive user interaction through ImagePreviewCard integration
  /// with adaptive state management and visual coordination.
  /// 
  /// **Preview Features:**
  /// - Processing state with loading indicator and progress feedback
  /// - Image display with proper sizing, clipping, and overlay controls
  /// - Empty state with user guidance and action prompts
  /// - Interactive controls with image removal and tooltip coordination
  /// 
  /// Returns image preview widget with comprehensive functionality and state management.
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
