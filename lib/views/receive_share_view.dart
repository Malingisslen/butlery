/// Comprehensive shared content reception view providing intelligent content analysis and import coordination for Flutter applications.
///
/// This module implements sophisticated shared content handling following Single Responsibility Principle,
/// specializing in content detection, platform extraction, and comprehensive import workflow coordination.
/// It provides complete shared content reception interface while maintaining clean separation from business logic,
/// data persistence, and state management through service integration and intelligent content processing.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles shared content UI presentation concerns through intelligent content analysis:
/// - **Content Detection Excellence**: Advanced content analysis with platform recognition and content type classification
/// - **Platform Extraction Intelligence**: Sophisticated social media extraction with automatic content retrieval
/// - **Import Workflow Coordination**: Comprehensive import path routing with content-specific navigation
/// - **Error Handling System**: Advanced error management with fallback options and user guidance
/// - **Swedish Localization Excellence**: Complete Swedish language support for content reception and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Content detection business logic and analysis algorithms (handled by ContentDetectorService and analysis infrastructure)
/// - Social media extraction implementation (handled by SocialMediaExtractor and platform services)
/// - Import processing and recipe parsing (handled by import ViewModels and parsing services)
/// - Analytics tracking implementation (handled by AnalyticsService and tracking infrastructure)
///
/// **Receive Share View Architecture:**
/// - **Intelligent Content Analysis**: Advanced content detection with platform recognition and type classification
/// - **Multi-Platform Extraction**: Comprehensive social media extraction with automatic content retrieval
/// - **Adaptive UI Flow**: Dynamic interface adaptation based on content type and platform detection
/// - **Error Recovery System**: Sophisticated error handling with multiple fallback options and user guidance
/// - **Analytics Integration**: Complete tracking system with import analytics and extraction monitoring
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to receive share view with shared content
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => ReceiveShareView(
///       content: sharedContent,
///       type: contentType,
///     ),
///   ),
/// );
/// 
/// // The view provides comprehensive shared content handling:
/// // - Intelligent content analysis with platform and type detection
/// // - Automatic extraction from social media platforms with error handling
/// // - Adaptive import workflow with content-specific navigation
/// // - Manual fallback options with user guidance and instruction
/// // - Analytics tracking with extraction monitoring and error reporting
/// 
/// // Content type handling examples:
/// // - Social media URLs: Automatic extraction with fallback to manual copy
/// // - Recipe URLs: Direct routing to URL import with web scraping
/// // - Recipe text: Direct routing to text import with validation
/// // - Generic text: Fallback routing with user confirmation
/// ```

// lib/views/receive_share_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/content_detector_service.dart' as content_detector;
import 'package:butlery/services/social_media_extractor.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/widgets/common/indicators/status_indicator.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

/// Comprehensive shared content reception view providing intelligent analysis and import workflow coordination.
///
/// Manages complete shared content handling enabling intelligent content detection, platform extraction,
/// adaptive import routing, and comprehensive error handling while maintaining clean separation between
/// UI presentation and business logic through service integration and sophisticated content processing.
///
/// **Core Responsibilities:**
/// - Advanced content analysis with platform recognition and content type classification through ContentDetectorService
/// - Social media extraction coordination with automatic content retrieval and error handling through SocialMediaExtractor
/// - Adaptive import workflow with content-specific navigation and user guidance through dynamic routing
/// - Analytics integration with extraction monitoring, error tracking, and user behavior analysis
/// - Swedish localized user experience with comprehensive error handling and recovery options
class ReceiveShareView extends StatefulWidget {
  /// Shared content for analysis and import processing.
  /// 
  /// Contains the shared content data enabling content detection, platform analysis,
  /// and comprehensive import workflow coordination through intelligent processing.
  final String content;
  
  /// Content type identifier for processing coordination.
  /// 
  /// Provides content type information enabling processing optimization,
  /// workflow coordination, and comprehensive content handling.
  final String type;

  /// Creates comprehensive shared content reception view with intelligent analysis and import coordination.
  /// 
  /// [content] Shared content for analysis and import processing
  /// [type] Content type identifier for processing coordination
  /// 
  /// Establishes shared content interface with intelligent content detection,
  /// platform extraction, and comprehensive import workflow coordination
  /// through service integration and adaptive processing architecture.
  const ReceiveShareView({
    super.key,
    required this.content,
    required this.type,
  });

  /// Creates receive share view state with service integration and lifecycle management.
  /// 
  /// Establishes stateful shared content interface enabling content analysis,
  /// platform extraction, and comprehensive import functionality through
  /// proper state lifecycle and service coordination.
  @override
  State<ReceiveShareView> createState() => _ReceiveShareViewState();
}

/// Receive share view state managing content analysis, platform extraction, and comprehensive import workflow coordination.
///
/// Handles complete shared content state management including content detection, social media extraction,
/// error handling, and user interaction handling while maintaining clean service integration
/// and proper lifecycle management through comprehensive content processing coordination.
class _ReceiveShareViewState extends State<ReceiveShareView> with ErrorHandlingMixin {
  /// Content detector service for intelligent content analysis and platform recognition.
  /// 
  /// Manages content detection enabling platform recognition, content type classification,
  /// and comprehensive content analysis through sophisticated detection algorithms.
  final content_detector.ContentDetectorService _detector = content_detector.ContentDetectorService();
  
  /// Social media extractor for automatic content retrieval and platform coordination.
  /// 
  /// Manages social media extraction enabling automatic content retrieval,
  /// platform-specific processing, and comprehensive extraction functionality.
  final SocialMediaExtractor _extractor = SocialMediaExtractor();
  
  /// Analytics service for tracking and monitoring coordination.
  /// 
  /// Manages analytics integration enabling extraction tracking, error monitoring,
  /// and comprehensive user behavior analysis throughout import workflow.
  final AnalyticsService _analytics = AnalyticsService();

  /// Content detection result for analysis coordination and workflow routing.
  /// 
  /// Stores detection results enabling workflow routing, UI adaptation,
  /// and comprehensive content processing coordination.
  late content_detector.ContentDetectionResult _detectionResult;
  
  /// Processing state for content analysis coordination.
  /// 
  /// Manages initial processing state enabling loading indicators, user feedback,
  /// and comprehensive processing experience with proper state management.
  bool _isProcessing = true;
  
  /// Extraction state for social media processing coordination.
  /// 
  /// Manages extraction processing state enabling loading indicators, user feedback,
  /// and comprehensive extraction experience with operation progress indication.
  bool _isExtracting = false;
  
  /// Extraction error state for error handling and user feedback coordination.
  /// 
  /// Stores extraction errors enabling error display, recovery options,
  /// and comprehensive error handling with user guidance.
  String? _extractionError;

  /// State initialization with content analysis and lifecycle preparation.
  /// 
  /// Initializes receive share state enabling content analysis, service integration,
  /// and comprehensive shared content functionality through proper lifecycle management
  /// and content processing coordination with user experience optimization.
  /// 
  /// **Initialization Process:**
  /// - Service initialization with content detection and extraction coordination
  /// - Content analysis triggering with intelligent detection and classification
  /// - State preparation with proper lifecycle management and resource allocation
  @override
  void initState() {
    super.initState();
    _analyzeContent();
  }

  /// Comprehensive resource disposal with service cleanup and lifecycle management coordination.
  /// 
  /// Performs complete resource cleanup preventing memory leaks and ensuring proper
  /// lifecycle management through systematic disposal of services, controllers,
  /// and state resources with comprehensive cleanup coordination.
  /// 
  /// **Disposal Features:**
  /// - Service disposal with memory leak prevention and proper resource management
  /// - State cleanup with comprehensive resource disposal and lifecycle coordination
  /// - Extraction service cleanup with proper resource management
  @override
  void dispose() {
    _extractor.dispose();
    super.dispose();
  }

  /// Intelligent content analysis with detection and classification coordination.
  /// 
  /// Performs comprehensive content analysis enabling platform recognition, content type classification,
  /// and import workflow routing through ContentDetectorService integration
  /// with proper analytics tracking and user experience optimization.
  /// 
  /// **Content Analysis Features:**
  /// - Intelligent content detection with platform recognition and type classification
  /// - Processing delay with user experience optimization and visual feedback
  /// - Analytics integration with import tracking and workflow monitoring
  /// - State management with proper detection result coordination and UI updates
  Future<void> _analyzeContent() async {
    debugPrint('📥 Analyserar delat innehåll...');

    // Simulera lite processing för bättre UX
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await _detector.detectContent(widget.content);
    if (mounted) setState(() {
      _detectionResult = result;
      _isProcessing = false;
    });

    // Logga att en delning mottagits
    _analytics.logImportStarted(
      source: 'share',
      platform: _detectionResult.platform?.toString().split('.').last,
    );
  }

  /// Text import navigation with content coordination and workflow routing.
  /// 
  /// Navigates to text import enabling content processing, source attribution,
  /// and comprehensive text import functionality through proper routing
  /// with content coordination and user experience optimization.
  /// 
  /// **Text Import Features:**
  /// - Content routing with text import integration and processing coordination
  /// - Source attribution with URL extraction and platform identification
  /// - Workflow coordination with proper navigation and state management
  void _navigateToTextImport() {
    Navigator.pushReplacementNamed(
      context,
      '/franSocialaMedier',
      arguments: {
        'text': widget.content,
        'sourceUrl': _detectionResult.extractedUrl ??
            'Importerad från ${_getSourceDescription()}',
      },
    );
  }

  /// Source description generation for user feedback and attribution coordination.
  /// 
  /// Generates appropriate source description enabling user understanding, content attribution,
  /// and comprehensive source identification through content type analysis
  /// with platform recognition and proper description formatting.
  /// 
  /// **Source Description Features:**
  /// - Content type analysis with appropriate description generation
  /// - Platform recognition with user-friendly naming and identification
  /// - Fallback description with generic attribution and proper handling
  /// 
  /// Returns source description string for user display and attribution.
  String _getSourceDescription() {
    if (_detectionResult.type == content_detector.ContentType.recipeText) {
      return 'delad text';
    } else if (_detectionResult.platform != null) {
      return _getPlatformName();
    } else {
      return 'annan app';
    }
  }

  /// URL import navigation with content coordination and workflow routing.
  /// 
  /// Navigates to URL import enabling web scraping, content extraction,
  /// and comprehensive URL import functionality through proper routing
  /// with fallback coordination and user experience optimization.
  /// 
  /// **URL Import Features:**
  /// - URL validation with extraction URL availability checking
  /// - Route navigation with URL import integration and processing coordination
  /// - Fallback handling with text import routing and user guidance
  void _navigateToUrlImport() {
    if (_detectionResult.extractedUrl != null) {
      Navigator.pushReplacementNamed(
        context,
        '/importViaUrl',
        arguments: _detectionResult.extractedUrl,
      );
    } else {
      // Om ingen URL, gå till text import istället
      _navigateToTextImport();
    }
  }

  /// Social media extraction with automatic content retrieval and error handling coordination.
  /// 
  /// Performs automatic social media extraction enabling content retrieval, error handling,
  /// and comprehensive extraction functionality through SocialMediaExtractor integration
  /// with analytics tracking and user feedback coordination.
  /// 
  /// **Social Media Extraction Features:**
  /// - URL validation with extraction URL availability checking
  /// - Extraction processing with loading state management and user feedback
  /// - Success handling with content routing and analytics tracking
  /// - Error handling with user feedback and recovery options
  /// - Analytics integration with extraction monitoring and error reporting
  Future<void> _extractFromSocialMedia() async {
    if (_detectionResult.extractedUrl == null) return;

    if (mounted) setState(() {
      _isExtracting = true;
      _extractionError = null;
    });

    await safeExecute(
      () async {
        final result = await _extractor.extractFromUrl(
          _detectionResult.extractedUrl!,
        );

        if (mounted) {
          if (result.success && result.extractedText != null) {
            // Logga lyckad extraktion
            _analytics.logImportSuccess(
              source: 'share_extraction',
              platform: _detectionResult.platform?.toString().split('.').last,
              recipeLength: result.extractedText!.length,
            );

            // Navigera till text import med extraherad text
            Navigator.pushReplacementNamed(
              context,
              '/franSocialaMedier',
              arguments: {
                'text': result.extractedText,
                'sourceUrl': _detectionResult.extractedUrl,
              },
            );
          } else {
            // Logga misslyckad extraktion
            final errorMessage = result.error ?? 'Kunde inte extrahera text';

            _analytics.logExtractionError(
              url: _detectionResult.extractedUrl!,
              platform: _detectionResult.platform ?? content_detector.SourcePlatform.unknown,
              error: errorMessage,
              errorType: result.metadata['reason'] as String?,
            );

            if (mounted) {
              if (mounted) setState(() {
                _extractionError = errorMessage;
                _isExtracting = false;
              });
            }
          }
        }
      },
      operationName: 'Extract from Social Media',
      customErrorMessage: null, // Handle error in catch block below
    ).catchError((e) {
      if (mounted) {
        // Logga oväntat fel
        _analytics.logExtractionError(
          url: _detectionResult.extractedUrl!,
          platform: _detectionResult.platform ?? content_detector.SourcePlatform.unknown,
          error: e.toString(),
          errorType: 'exception',
        );

        if (mounted) setState(() {
          _extractionError = 'Ett fel uppstod: ${e.toString()}';
          _isExtracting = false;
        });
      }
    });
  }

  /// Manual copy fallback handling with user guidance and analytics coordination.
  /// 
  /// Handles manual copy fallback enabling user guidance, instruction display,
  /// and comprehensive manual import workflow through dialog presentation
  /// with analytics tracking and user experience optimization.
  /// 
  /// **Manual Copy Features:**
  /// - Analytics tracking with fallback reason analysis and user behavior monitoring
  /// - Instruction dialog with step-by-step guidance and platform-specific instructions
  /// - User confirmation with dialog workflow and navigation coordination
  /// - Text import routing with fallback navigation and user experience continuity
  void _handleManualCopy() {
    // Logga att användaren valde manuell kopiering
    _analytics.logManualCopyFallback(
      platform: _detectionResult.platform ?? content_detector.SourcePlatform.unknown,
      reason: _extractionError != null ? 'after_error' : 'user_choice',
    );

    DialogFactory.showConfirmation(
      context,
      title: 'Manuell kopiering',
      message: '1. Gå tillbaka till ${_getPlatformName()}\n'
               '2. Kopiera recepttexten från inlägget\n'
               '3. Kom tillbaka hit och välj "Klistra in text"',
      confirmText: 'Klistra in text',
      cancelText: 'Avbryt',
    ).then((confirmed) {
      if (confirmed == true) {
        _navigateToTextImport();
      }
    });
  }

  /// Comprehensive shared content interface construction with adaptive UI and processing coordination.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete shared content interface featuring adaptive UI flow,
  /// processing states, and comprehensive content handling through intelligent
  /// content analysis and dynamic interface adaptation with user experience optimization.
  /// 
  /// **Interface Architecture:**
  /// - Processing state with loading interface and progress indication
  /// - Extraction state with platform-specific loading and user feedback
  /// - Content view with detection results and action coordination
  /// - Adaptive UI flow with content-specific interface and workflow routing
  /// 
  /// Returns complete shared content interface with comprehensive functionality and adaptive design.
  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const LoadingScaffold(
        title: 'Importera recept',
        loadingMessage: 'Analyserar innehåll...',
      );
    }
    
    if (_isExtracting) {
      return LoadingScaffold(
        title: 'Importera recept',
        loadingMessage: 'Hämtar recept från ${_getPlatformName()}...',
      );
    }
    
    return BaseScaffold(
      title: 'Importera recept',
      body: _buildContentView(),
    );
  }

  /// Content view construction with detection results and action coordination.
  /// 
  /// Constructs content view enabling detection result display, content preview,
  /// and comprehensive action coordination through proper layout management
  /// with user interface optimization and interactive element integration.
  /// 
  /// **Content View Features:**
  /// - Detection header with content type and platform information display
  /// - Content preview with scrollable text display and proper formatting
  /// - Action buttons with content-specific functionality and workflow routing
  /// - Responsive layout with proper spacing and visual hierarchy
  /// 
  /// Returns content view widget with comprehensive functionality and user interaction.
  Widget _buildContentView() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetectionHeader(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildContentPreview(),
          const Spacer(),
          _buildActionButtons(),
          const SizedBox(height: AppDimensions.spacingL),
        ],
      ),
    );
  }

  /// Detection header construction with content type and platform information display.
  /// 
  /// Constructs detection header enabling content type visualization, platform identification,
  /// and comprehensive detection result display through proper icon selection,
  /// color coordination, and information presentation with visual hierarchy.
  /// 
  /// **Detection Header Features:**
  /// - Content type visualization with appropriate icons and color coordination
  /// - Platform identification with user-friendly naming and visual indication
  /// - URL display with extracted URL presentation and proper formatting
  /// - Visual hierarchy with proper spacing and alignment coordination
  /// 
  /// Returns detection header widget with comprehensive content type and platform information.
  Widget _buildDetectionHeader() {
    IconData icon;
    String title;
    Color color;

    switch (_detectionResult.type) {
      case content_detector.ContentType.socialMediaUrl:
        icon = Icons.link;
        title = 'URL från ${_getPlatformName()}';
        color = AppColors.primaryBlue;
        break;
      case content_detector.ContentType.recipeText:
        icon = Icons.restaurant_menu;
        title = 'Recepttext detekterad!';
        color = AppColors.success;
        break;
      case content_detector.ContentType.recipeUrl:
        icon = Icons.public;
        title = 'Receptlänk detekterad';
        color = AppColors.primaryBlue;
        break;
      default:
        icon = Icons.text_fields;
        title = 'Textinnehåll';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Row(
      children: [
        StatusIndicator(
          icon: icon,
          color: color,
        ),
        const SizedBox(width: AppDimensions.spacingL),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleLarge),
              if (_detectionResult.extractedUrl != null) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  _detectionResult.extractedUrl!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Content preview construction with scrollable text display and proper formatting.
  /// 
  /// Constructs content preview enabling shared content display, proper formatting,
  /// and comprehensive text presentation through TextDisplayCard integration
  /// with responsive design and visual coordination.
  /// 
  /// **Content Preview Features:**
  /// - Scrollable text display with proper height constraints and responsive design
  /// - Visual formatting with background color and border coordination
  /// - Text styling with theme integration and readability optimization
  /// - Height constraints with screen size adaptation and user experience optimization
  /// 
  /// Returns content preview widget with comprehensive text display and formatting.
  Widget _buildContentPreview() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: TextDisplayCard(
        text: widget.content,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderColor: Theme.of(context).dividerColor,
        textStyle: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  /// Action buttons construction with content-specific functionality and workflow coordination.
  /// 
  /// Constructs action buttons enabling content-specific functionality, workflow routing,
  /// and comprehensive user interaction through adaptive button presentation
  /// with proper error handling and user guidance coordination.
  /// 
  /// **Action Button Features:**
  /// - Content-specific functionality with adaptive button presentation and workflow routing
  /// - Error handling with user feedback and recovery options display
  /// - Social media integration with automatic extraction and manual fallback options
  /// - Recipe URL handling with web scraping integration and direct import routing
  /// - Generic content handling with fallback options and user guidance
  /// 
  /// Returns action buttons widget with comprehensive functionality and content-specific coordination.
  Widget _buildActionButtons() {
    switch (_detectionResult.type) {
      case content_detector.ContentType.socialMediaUrl:
        // För sociala medier - vi kan nu extrahera automatiskt!
        return Column(
          children: [
            if (_extractionError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        _extractionError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingL),
            ],
            ElevatedButton.icon(
              onPressed: _extractFromSocialMedia,
              icon: const Icon(Icons.download),
              label: Text(
                _extractionError != null
                    ? 'Försök igen'
                    : 'Hämta recept automatiskt',
              ),
              style: ComponentThemes.primaryButtonStyle,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text('eller', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppDimensions.spacingS),
            OutlinedButton.icon(
              onPressed: _handleManualCopy,
              icon: const Icon(Icons.content_paste),
              label: const Text('Kopiera manuellt'),
              style: ComponentThemes.outlinedButtonStyle,
            ),
          ],
        );

      case content_detector.ContentType.recipeUrl:
        // Vanlig receptwebbsida - vi kan scrapa denna
        return Column(
          children: [
            Text(
              'Receptlänk från webbsida detekterad!',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton.icon(
              onPressed: _navigateToUrlImport,
              icon: const Icon(Icons.download),
              label: const Text('Hämta recept från webbsida'),
              style: ComponentThemes.primaryButtonStyle,
            ),
          ],
        );

      case content_detector.ContentType.recipeText:
        // Ren recepttext - perfekt!
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      'Recepttext detekterad! Vi kan importera detta.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.success,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Fortsätt med import'),
              style: ComponentThemes.primaryButtonStyle,
            ),
          ],
        );

      default:
        // Vanlig text utan recept
        return Column(
          children: [
            Text(
              'Ingen receptinformation hittades i texten.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            OutlinedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.edit),
              label: const Text('Försök ändå'),
              style: ComponentThemes.outlinedButtonStyle,
            ),
          ],
        );
    }
  }

  /// Platform name generation for user-friendly display and identification coordination.
  /// 
  /// Generates user-friendly platform names enabling platform identification,
  /// user communication, and comprehensive platform recognition through
  /// platform enumeration analysis with proper fallback handling.
  /// 
  /// **Platform Name Features:**
  /// - Platform enumeration analysis with user-friendly name generation
  /// - Comprehensive platform support with major social media platform recognition
  /// - Fallback handling with unknown platform identification and proper messaging
  /// 
  /// Returns user-friendly platform name string for display and communication.
  String _getPlatformName() {
    switch (_detectionResult.platform) {
      case content_detector.SourcePlatform.instagram:
        return 'Instagram';
      case content_detector.SourcePlatform.facebook:
        return 'Facebook';
      case content_detector.SourcePlatform.tiktok:
        return 'TikTok';
      case content_detector.SourcePlatform.youtube:
        return 'YouTube';
      case content_detector.SourcePlatform.website:
        return 'Webbsida';
      default:
        return 'Okänd källa';
    }
  }
}