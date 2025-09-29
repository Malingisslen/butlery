/// Comprehensive text import view providing intelligent recipe parsing and content processing for Flutter applications.
///
/// This module implements sophisticated text-based recipe import following Single Responsibility Principle,
/// specializing in text parsing, recipe validation, content processing, and comprehensive import workflow coordination.
/// It provides complete text import interface while maintaining clean separation from business logic,
/// data persistence, and state management through TextImportViewModel integration and modern component architecture.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles text import UI presentation concerns through intelligent content processing:
/// - **Text Processing Excellence**: Advanced text input handling with real-time validation and parsing coordination
/// - **Recipe Parsing Intelligence**: Sophisticated recipe extraction with ingredient and instruction identification
/// - **Import Workflow Coordination**: Comprehensive import path management with validation and error handling
/// - **Source Attribution System**: Advanced source URL tracking with proper content attribution and display
/// - **Swedish Localization Excellence**: Complete Swedish language support for import operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Text parsing business logic and recipe extraction algorithms (handled by TextImportViewModel and parsing services)
/// - Recipe creation and editing functionality (handled by SkrivSjalvReceptView and recipe editing infrastructure)
/// - Source URL validation and processing (handled by URL validation services and content detection)
/// - Analytics tracking implementation (handled by AnalyticsService and import tracking infrastructure)
///
/// **Text Import View Architecture:**
/// - **Intelligent Text Processing**: Advanced text input with real-time validation and parsing feedback
/// - **Recipe Detection System**: Sophisticated content analysis with ingredient and instruction recognition
/// - **Adaptive Import Flow**: Dynamic workflow adaptation based on content quality and parsing success
/// - **Source URL Integration**: Comprehensive source attribution with URL display and validation
/// - **Error Recovery System**: Advanced error handling with user guidance and recovery options
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to text import view with initial content
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => FranSocialaMedierView(
///       initialText: extractedText,
///       sourceUrl: contentSourceUrl,
///     ),
///   ),
/// );
/// 
/// // The view provides comprehensive text import functionality:
/// // - Intelligent text processing with real-time validation and parsing feedback
/// // - Recipe parsing with ingredient and instruction extraction
/// // - Source attribution with URL display and content validation
/// // - Automatic navigation to recipe editing upon successful parsing
/// // - Error handling with user guidance and recovery options
/// 
/// // Content processing examples:
/// // - Social media text: Automatic parsing with platform attribution
/// // - Recipe URLs: Source URL display with content extraction
/// // - Manual text input: Real-time validation with parsing feedback
/// // - Template creation: Automatic navigation to recipe editing workflow
/// ```

// lib/views/fran_sociala_medier_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/source_url_display.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
/// Comprehensive text import view providing intelligent recipe parsing and content processing through advanced text analysis.
///
/// Manages complete text-based import interface enabling recipe parsing, content validation, import workflow coordination,
/// and comprehensive text processing while maintaining clean separation between UI presentation
/// and business logic through TextImportViewModel integration and specialized component architecture.
///
/// **Core Responsibilities:**
/// - Advanced text processing with real-time validation, parsing feedback, and content quality assessment
/// - Recipe parsing coordination with ingredient extraction, instruction identification, and template creation
/// - Import workflow management with automatic navigation, validation, and error handling through service integration 
/// - Source attribution handling with URL display, content validation, and proper attribution tracking
/// - Swedish localized import experience with comprehensive user feedback and instructional guidance
class FranSocialaMedierView extends StatelessWidget {
  /// Initial text content for automatic parsing and import processing.
  /// 
  /// Contains the extracted text content enabling automatic recipe parsing,
  /// import workflow initialization, and comprehensive content processing.
  final String? initialText;
  
  /// Source URL for content attribution and validation coordination.
  /// 
  /// Provides source URL information enabling content attribution,
  /// validation tracking, and comprehensive source display.
  final String? sourceUrl;

  /// Creates comprehensive text import view with intelligent parsing and content processing coordination.
  /// 
  /// [initialText] Initial text content for automatic parsing and import processing
  /// [sourceUrl] Source URL for content attribution and validation coordination
  /// 
  /// Establishes text import interface with intelligent recipe parsing,
  /// content validation, and comprehensive import workflow coordination
  /// through TextImportViewModel integration and automatic processing architecture.
  const FranSocialaMedierView({
    super.key,
    this.initialText,
    this.sourceUrl,
  });

  /// Comprehensive text import interface construction with ViewModel integration and automatic processing coordination.
  /// 
  /// [context] Build context for theme access and navigation coordination
  /// 
  /// Constructs complete text import interface featuring intelligent text processing,
  /// automatic recipe parsing, and comprehensive import workflow through TextImportViewModel
  /// integration with source attribution and automatic navigation coordination.
  /// 
  /// **Interface Architecture:**
  /// - TextImportViewModel integration with service locator and dependency injection
  /// - Source URL configuration with attribution tracking and display coordination
  /// - Initial text processing with automatic parsing and template creation
  /// - Post-frame callback coordination with navigation and error handling
  /// 
  /// Returns complete text import interface with comprehensive functionality and automatic processing.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final viewModel = ServiceLocator.get<TextImportViewModel>();

        // Sätt sourceUrl om den finns
        if (sourceUrl != null) {
          viewModel.setSourceUrl(sourceUrl!);
        }

        return viewModel;
      },
      child: _FranSocialaMedierViewContent(
        initialText: initialText,
        sourceUrl: sourceUrl,
      ),
    );
  }
}

/// Text import view content managing text processing, parsing coordination, and comprehensive import workflow.
///
/// Handles complete text import state management including text input, recipe parsing, navigation coordination,
/// and error handling while maintaining clean TextImportViewModel integration and proper lifecycle management
/// through comprehensive import workflow coordination and user experience optimization.
class _FranSocialaMedierViewContent extends StatefulWidget {
  final String? initialText;
  final String? sourceUrl;
  
  /// Creates text import view content with parsing coordination and workflow management.
  /// 
  /// Establishes stateful content interface enabling text processing, recipe parsing,
  /// and comprehensive import functionality through proper ViewModel integration
  /// and navigation coordination with user experience optimization.
  const _FranSocialaMedierViewContent({
    this.initialText,
    this.sourceUrl,
  });

  @override
  State<_FranSocialaMedierViewContent> createState() => _FranSocialaMedierViewContentState();
}

class _FranSocialaMedierViewContentState extends State<_FranSocialaMedierViewContent> {
  late TextEditingController _textController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    _textController = TextEditingController(text: widget.initialText ?? '');
    
    // Uppdatera ViewModel med initial text efter att widgeten är byggd
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialText != null && widget.initialText!.isNotEmpty) {
        final viewModel = context.read<TextImportViewModel>();
        viewModel.updateInputText(widget.initialText!);
        viewModel.parseText();
      }
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Text parsing and navigation coordination with recipe template creation.
  /// 
  /// Performs comprehensive text parsing enabling recipe extraction, template creation,
  /// and automatic navigation to recipe editing through TextImportViewModel integration
  /// with error handling and user feedback coordination.
  /// 
  /// [context] Build context for ViewModel access and navigation coordination
  /// 
  /// **Parsing Process:**
  /// - Text parsing with ingredient and instruction extraction through ViewModel
  /// - Success handling with automatic navigation to recipe editing interface
  /// - Error handling with user feedback through error snackbar display
  /// - Template creation with parsed recipe data and editing workflow initialization
  Future<void> _parseAndNavigate(BuildContext context) async {
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

  /// Comprehensive text import interface construction with processing workflow and user input coordination.
  /// 
  /// [context] Build context for theme access and ViewModel integration
  /// 
  /// Constructs complete text import interface featuring text input, source attribution,
  /// parsing controls, and comprehensive user experience through TextImportViewModel
  /// integration with real-time validation and processing feedback coordination.
  /// 
  /// **Interface Architecture:**
  /// - Instructional guidance with user education and best practices display
  /// - Source URL attribution with proper content source display and validation
  /// - Expandable text input with example content and real-time validation
  /// - Processing controls with parsing coordination and loading state management
  /// - Error handling with user feedback and recovery guidance
  /// 
  /// Returns complete text import interface with comprehensive functionality and user guidance.
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TextImportViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Från sociala medier')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instruktionstext
            _buildInstructions(context),
            const SizedBox(height: AppDimensions.spacingXl),

            // Visa om receptet kommer från URL
            if (viewModel.sourceUrl != null) ...[
              SourceUrlDisplay(sourceUrl: viewModel.sourceUrl!),
              const SizedBox(height: AppDimensions.spacingM),
            ],

            // Textfält för recept
            _buildTextInput(context, viewModel),
            const SizedBox(height: AppDimensions.spacingXl),

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
              const SizedBox(height: AppDimensions.spacingM),
              StateWidget.error(
                message: viewModel.error!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Instructional guidance construction with user education and best practices display.
  /// 
  /// [context] Build context for theme access and styling coordination
  /// 
  /// Constructs instructional guidance enabling user education, best practices display,
  /// and comprehensive import guidance through proper visual hierarchy,
  /// icon coordination, and informational content presentation.
  /// 
  /// **Instruction Features:**
  /// - Visual hierarchy with icon and title coordination for clear information presentation
  /// - Best practices guidance with ingredient and instruction organization tips
  /// - Platform support information with social media compatibility guidance
  /// - Responsive design with proper spacing and visual coordination
  /// 
  /// Returns instructional guidance widget with comprehensive user education and best practices.
  Widget _buildInstructions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                'Tips för bästa resultat',
                style: AppTextStyles.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            '• Klistra in hela receptet inklusive ingredienser\n'
            '• Se till att ingredienser kommer före instruktioner\n'
            '• Texten kan komma från Instagram, TikTok, Facebook etc.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Textinput-widget construction med expanderbar höjd och automatisk validering.
  /// 
  /// [context] Build context för tema-access och ViewModel-integration
  /// [viewModel] TextImportViewModel för texthantering och validering
  /// 
  /// Konstruerar textinput-interface med expanderbar textruta,
  /// automatisk höjdjustering och real-time validering genom TextEditingController
  /// integration med ViewModel state coordination och användarvänlig feedback.
  /// 
  /// **Textinput Features:**
  /// - Expanderbar textruta med automatisk höjdjustering baserat på innehåll
  /// - Real-time synkronisering mellan TextEditingController och ViewModel state
  /// - Placeholder-text med exempel och användarguide för optimal importupplevelse
  /// - Responsiv design med proper spacing och visuell hierarki
  /// - Text validering och längd-feedback för användarguidning och kvalitetskontroll
  /// 
  /// Returns textinput widget med komplett funktionalitet och användarupplevelse.
  Widget _buildTextInput(BuildContext context, TextImportViewModel viewModel) {
    // Synkronisera ViewModel-text med controller om de skiljer sig åt
    if (_isInitialized && _textController.text != viewModel.inputText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_textController.text != viewModel.inputText) {
          _textController.text = viewModel.inputText;
        }
      });
    }

    return Container(
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 400,
      ),
      child: TextField(
        controller: _textController,
        onChanged: viewModel.updateInputText,
        decoration: InputDecoration(
          hintText: 'Klistra in recepttext här...\n\n'
              'Exempel:\n'
              'Ingredienser:\n'
              '- 500g pasta\n'
              '- 2 vitlöksklyftor\n'
              '\n'
              'Instruktioner:\n'
              '1. Koka pastan enligt förpackningen\n'
              '2. Hacka vitlöken fint...',
          hintMaxLines: 10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          filled: true,
          fillColor: AppColors.backgroundTint,
        ),
        keyboardType: TextInputType.multiline,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.bodyMedium,
      ),
    );
  }
}
