/// Shared content reception view with intelligent content analysis and import routing.
/// Handles content from share intents, detecting platform/type and routing to appropriate
/// import workflow. Supports social media extraction with manual fallback options.
/// **Key Features:**
/// - Content detection with platform recognition
/// - Social media extraction (Instagram, Facebook, etc.)
/// - Adaptive import routing based on content type
/// - Manual fallback with user guidance

// lib/views/receive_share_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/content_detector_service.dart'
    as content_detector;
import 'package:butlery/services/social_media_extractor.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/widgets/common/indicators/status_indicator.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/widgets/common/layout_components.dart';

/// Stateful widget for shared content reception with intelligent content routing.
class ReceiveShareView extends StatefulWidget {
  /// Shared content to analyze and import.
  final String content;

  /// Content type identifier.
  final String type;

  const ReceiveShareView({
    super.key,
    required this.content,
    required this.type,
  });

  @override
  State<ReceiveShareView> createState() => _ReceiveShareViewState();
}

/// State class managing content analysis, extraction, and import routing.
class _ReceiveShareViewState extends State<ReceiveShareView>
    with ErrorHandlingMixin {
  late final content_detector.ContentDetectorService _detector;
  late final SocialMediaExtractor _extractor;
  late final AnalyticsService _analytics;

  late content_detector.ContentDetectionResult _detectionResult;
  bool _isProcessing = true;
  bool _isExtracting = false;
  String? _extractionError;

  @override
  void initState() {
    super.initState();
    _detector = ServiceLocator.get<content_detector.ContentDetectorService>();
    _extractor = ServiceLocator.get<SocialMediaExtractor>();
    _analytics = ServiceLocator.get<AnalyticsService>();
    _analyzeContent();
  }

  @override
  void dispose() {
    _extractor.dispose();
    super.dispose();
  }

  /// Analyze content and classify type/platform for routing.
  Future<void> _analyzeContent() async {
    // Simulate processing for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await _detector.detectContent(widget.content);
    if (mounted) {
      setState(() {
        _detectionResult = result;
        _isProcessing = false;
      });
    }

    // Logga att en delning mottagits
    _analytics.logImportStarted(
      source: 'share',
      platform: _detectionResult.platform?.toString().split('.').last,
    );
  }

  /// Navigate to text import with source attribution.
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

  /// Get user-friendly source description based on content type.
  String _getSourceDescription() {
    if (_detectionResult.type == content_detector.ContentType.recipeText) {
      return 'delad text';
    } else if (_detectionResult.platform != null) {
      return _getPlatformName();
    } else {
      return 'annan app';
    }
  }

  /// Navigate to URL import or fall back to text import.
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

  /// Extract content from social media URL with analytics tracking.
  Future<void> _extractFromSocialMedia() async {
    if (_detectionResult.extractedUrl == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isExtracting = true;
        _extractionError = null;
      });
    }

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
              platform: _detectionResult.platform ??
                  content_detector.SourcePlatform.unknown,
              error: errorMessage,
              errorType: result.metadata['reason'] as String?,
            );

            if (mounted) {
              if (mounted) {
                setState(() {
                  _extractionError = errorMessage;
                  _isExtracting = false;
                });
              }
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
          platform: _detectionResult.platform ??
              content_detector.SourcePlatform.unknown,
          error: e.toString(),
          errorType: 'exception',
        );

        if (mounted) {
          setState(() {
            _extractionError = 'Ett fel uppstod: ${e.toString()}';
            _isExtracting = false;
          });
        }
      }
    });
  }

  /// Show manual copy instructions and navigate to text import.
  void _handleManualCopy() {
    // Logga att användaren valde manuell kopiering
    _analytics.logManualCopyFallback(
      platform:
          _detectionResult.platform ?? content_detector.SourcePlatform.unknown,
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

  /// Build UI with adaptive content based on processing/extraction state.
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

    return BaseScaffold(title: 'Importera recept', body: _buildContentView());
  }

  /// Build content view with detection header, preview, and action buttons.
  Widget _buildContentView() {
    // ✅ RESPONSIVE: Center and constrain content on large screens
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 700,
            desktop: 800,
          ),
        ),
        child: Padding(
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
        ),
      ),
    );
  }

  /// Build header showing detected content type and platform.
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
        StatusIndicator(icon: icon, color: color),
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
                  style: AppTextStyles.bodySmall.copyWith(
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

  /// Build scrollable content preview with height constraints.
  Widget _buildContentPreview() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: TextDisplayCard(
        text: widget.content,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderColor: Theme.of(context).dividerColor,
        textStyle: AppTextStyles.bodyMedium,
      ),
    );
  }

  /// Build action buttons based on detected content type.
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
                  color: AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusM,
                  ),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        _extractionError!,
                        style: AppTextStyles.bodySmall.copyWith(
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
            Text('eller', style: AppTextStyles.bodySmall),
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
              style: AppTextStyles.titleSmall,
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
                color: AppColors.success.withValues(alpha: AppDimensions.opacityVeryLight),
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusM,
                ),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      'Recepttext detekterad! Vi kan importera detta.',
                      style: AppTextStyles.bodyMedium.copyWith(
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
              style: AppTextStyles.bodyMedium,
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

  /// Get user-friendly platform name from detected platform.
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
