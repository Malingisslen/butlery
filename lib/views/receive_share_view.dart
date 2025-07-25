// lib/views/receive_share_view.dart

import 'package:flutter/material.dart';
import '../services/content_detector_service.dart';
import '../services/social_media_extractor.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../widgets/common/scaffolds/base_scaffold.dart';
import '../core/dialogs/dialog_factory.dart';
import '../core/mixins/error_handling_mixin.dart';

/// View för att ta emot och hantera delningar från andra appar
class ReceiveShareView extends StatefulWidget {
  final String content;
  final String type;

  const ReceiveShareView({
    super.key,
    required this.content,
    required this.type,
  });

  @override
  State<ReceiveShareView> createState() => _ReceiveShareViewState();
}

class _ReceiveShareViewState extends State<ReceiveShareView> with ErrorHandlingMixin {
  final ContentDetectorService _detector = ContentDetectorService();
  final SocialMediaExtractor _extractor = SocialMediaExtractor();
  final AnalyticsService _analytics = AnalyticsService();

  late ContentDetectionResult _detectionResult;
  bool _isProcessing = true;
  bool _isExtracting = false;
  String? _extractionError;

  @override
  void initState() {
    super.initState();
    _analyzeContent();
  }

  @override
  void dispose() {
    _extractor.dispose();
    super.dispose();
  }

  Future<void> _analyzeContent() async {
    debugPrint('📥 Analyserar delat innehåll...');

    // Simulera lite processing för bättre UX
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await _detector.detectContent(widget.content);
    setState(() {
      _detectionResult = result;
      _isProcessing = false;
    });

    // Logga att en delning mottagits
    _analytics.logImportStarted(
      source: 'share',
      platform: _detectionResult.platform?.toString().split('.').last,
    );
  }

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

  String _getSourceDescription() {
    if (_detectionResult.type == ContentType.recipeText) {
      return 'delad text';
    } else if (_detectionResult.platform != null) {
      return _getPlatformName();
    } else {
      return 'annan app';
    }
  }

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

  /// Extrahera text från social media URL
  Future<void> _extractFromSocialMedia() async {
    if (_detectionResult.extractedUrl == null) return;

    setState(() {
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
              platform: _detectionResult.platform ?? SourcePlatform.unknown,
              error: errorMessage,
              errorType: result.metadata['reason'] as String?,
            );

            if (mounted) {
              setState(() {
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
          platform: _detectionResult.platform ?? SourcePlatform.unknown,
          error: e.toString(),
          errorType: 'exception',
        );

        setState(() {
          _extractionError = 'Ett fel uppstod: ${e.toString()}';
          _isExtracting = false;
        });
      }
    });
  }

  /// Hantera när användare väljer manuell kopiering
  void _handleManualCopy() {
    // Logga att användaren valde manuell kopiering
    _analytics.logManualCopyFallback(
      platform: _detectionResult.platform ?? SourcePlatform.unknown,
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

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return LoadingScaffold(
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


  Widget _buildContentView() {
    return Padding(
      padding: EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetectionHeader(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildContentPreview(),
          const Spacer(),
          _buildActionButtons(),
          SizedBox(height: AppDimensions.spacingL),
        ],
      ),
    );
  }

  Widget _buildDetectionHeader() {
    IconData icon;
    String title;
    Color color;

    switch (_detectionResult.type) {
      case ContentType.socialMediaUrl:
        icon = Icons.link;
        title = 'URL från ${_getPlatformName()}';
        color = AppColors.primaryBlue;
        break;
      case ContentType.recipeText:
        icon = Icons.restaurant_menu;
        title = 'Recepttext detekterad!';
        color = AppColors.success;
        break;
      case ContentType.recipeUrl:
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
        Container(
          padding: EdgeInsets.all(AppDimensions.spacingS),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(icon, color: color, size: AppDimensions.iconSizeAction),
        ),
        SizedBox(width: AppDimensions.spacingL),
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

  Widget _buildContentPreview() {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: SingleChildScrollView(
        child: Text(
          widget.content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_detectionResult.type) {
      case ContentType.socialMediaUrl:
        // För sociala medier - vi kan nu extrahera automatiskt!
        return Column(
          children: [
            if (_extractionError != null) ...[
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    SizedBox(width: AppDimensions.spacingS),
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
              SizedBox(height: AppDimensions.spacingL),
            ],
            ElevatedButton.icon(
              onPressed: _extractFromSocialMedia,
              icon: const Icon(Icons.download),
              label: Text(
                _extractionError != null
                    ? 'Försök igen'
                    : 'Hämta recept automatiskt',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.cardWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
            ),
            SizedBox(height: AppDimensions.spacingL),
            Text('eller', style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: AppDimensions.spacingS),
            OutlinedButton.icon(
              onPressed: _handleManualCopy,
              icon: const Icon(Icons.content_paste),
              label: const Text('Kopiera manuellt'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                side: BorderSide(color: AppColors.primaryBlue),
              ),
            ),
          ],
        );

      case ContentType.recipeUrl:
        // Vanlig receptwebbsida - vi kan scrapa denna
        return Column(
          children: [
            Text(
              'Receptlänk från webbsida detekterad!',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppDimensions.spacingL),
            ElevatedButton.icon(
              onPressed: _navigateToUrlImport,
              icon: const Icon(Icons.download),
              label: const Text('Hämta recept från webbsida'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.cardWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
            ),
          ],
        );

      case ContentType.recipeText:
        // Ren recepttext - perfekt!
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: AppDimensions.spacingS),
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
            SizedBox(height: AppDimensions.spacingL),
            ElevatedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Fortsätt med import'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.cardWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
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
            SizedBox(height: AppDimensions.spacingL),
            OutlinedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.edit),
              label: const Text('Försök ändå'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                side: BorderSide(color: AppColors.primaryBlue),
              ),
            ),
          ],
        );
    }
  }

  String _getPlatformName() {
    switch (_detectionResult.platform) {
      case SourcePlatform.instagram:
        return 'Instagram';
      case SourcePlatform.facebook:
        return 'Facebook';
      case SourcePlatform.tiktok:
        return 'TikTok';
      case SourcePlatform.youtube:
        return 'YouTube';
      case SourcePlatform.website:
        return 'Webbsida';
      default:
        return 'Okänd källa';
    }
  }
}
