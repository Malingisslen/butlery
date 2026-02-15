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
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/widgets/common/indicators/status_indicator.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
    await Future.delayed(AppDimensions.animationDurationLong);

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
            context.l10n.importImportedFrom(_getSourceDescription()),
      },
    );
  }

  /// Get user-friendly source description based on content type.
  String _getSourceDescription() {
    if (_detectionResult.type == content_detector.ContentType.recipeText) {
      return context.l10n.importSharedText;
    } else if (_detectionResult.platform != null) {
      return _getPlatformName();
    } else {
      return context.l10n.importOtherApp;
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
            final errorMessage =
                result.error ?? context.l10n.importCouldNotExtractText;

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
            _extractionError = context.l10n
                .errorWithContext(context.l10n.importExtraction, e.toString());
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
      title: context.l10n.importManualCopy,
      message: context.l10n.importManualCopyInstructions(_getPlatformName()),
      confirmText: context.l10n.importPasteText,
      cancelText: context.l10n.commonCancel,
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
      return LoadingScaffold(
        title: context.l10n.importRecipeTitle,
        loadingMessage: context.l10n.importAnalyzingContent,
      );
    }

    if (_isExtracting) {
      return LoadingScaffold(
        title: context.l10n.importRecipeTitle,
        loadingMessage:
            context.l10n.importFetchingFromPlatform(_getPlatformName()),
      );
    }

    return BaseScaffold(
        title: context.l10n.importRecipeTitle, body: _buildContentView());
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
        title = context.l10n.importUrlFromPlatform(_getPlatformName());
        color = Theme.of(context).colorScheme.primary;
        break;
      case content_detector.ContentType.recipeText:
        icon = Icons.restaurant_menu;
        title = context.l10n.importRecipeTextDetected;
        color = context.butleryColors.success;
        break;
      case content_detector.ContentType.recipeUrl:
        icon = Icons.public;
        title = context.l10n.importRecipeLinkDetected;
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        icon = Icons.text_fields;
        title = context.l10n.importTextContent;
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
              Builder(builder: (context) {
                final cs = Theme.of(context).colorScheme;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: cs.error
                        .withValues(alpha: AppDimensions.opacityVeryLight),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusM,
                    ),
                    border: Border.all(color: cs.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: cs.error),
                      const SizedBox(width: AppDimensions.spacingS),
                      Expanded(
                        child: Text(
                          _extractionError!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppDimensions.spacingL),
            ],
            ElevatedButton.icon(
              onPressed: _extractFromSocialMedia,
              icon: const Icon(Icons.download),
              label: Text(
                _extractionError != null
                    ? context.l10n.commonRetry
                    : context.l10n.importFetchAutomatically,
              ),
              style: ComponentThemes.primaryButtonStyle(
                  Theme.of(context).colorScheme),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(context.l10n.commonOr, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppDimensions.spacingS),
            OutlinedButton.icon(
              onPressed: _handleManualCopy,
              icon: const Icon(Icons.content_paste),
              label: Text(context.l10n.importCopyManually),
              style: ComponentThemes.outlinedButtonStyle(
                  Theme.of(context).colorScheme),
            ),
          ],
        );

      case content_detector.ContentType.recipeUrl:
        // Vanlig receptwebbsida - vi kan scrapa denna
        return Column(
          children: [
            Text(
              context.l10n.importWebRecipeLinkDetected,
              style: AppTextStyles.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton.icon(
              onPressed: _navigateToUrlImport,
              icon: const Icon(Icons.download),
              label: Text(context.l10n.importFetchFromWebsite),
              style: ComponentThemes.primaryButtonStyle(
                  Theme.of(context).colorScheme),
            ),
          ],
        );

      case content_detector.ContentType.recipeText:
        // Ren recepttext - perfekt!
        return Column(
          children: [
            Builder(builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: context.butleryColors.success
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusM,
                  ),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: context.butleryColors.success),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        context.l10n.importRecipeTextCanImport,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.butleryColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.l10n.importContinueWithImport),
              style: ComponentThemes.primaryButtonStyle(
                  Theme.of(context).colorScheme),
            ),
          ],
        );

      default:
        // Vanlig text utan recept
        return Column(
          children: [
            Text(
              context.l10n.importNoRecipeInfoFound,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            OutlinedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.edit),
              label: Text(context.l10n.importTryAnyway),
              style: ComponentThemes.outlinedButtonStyle(
                  Theme.of(context).colorScheme),
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
        return context.l10n.importWebsite;
      default:
        return context.l10n.importUnknownSource;
    }
  }
}
