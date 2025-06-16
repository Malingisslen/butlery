// lib/views/receive_share_view.dart

import 'package:flutter/material.dart';
import '../services/content_detector_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';

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

class _ReceiveShareViewState extends State<ReceiveShareView> {
  final ContentDetectorService _detector = ContentDetectorService();
  late ContentDetectionResult _detectionResult;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _analyzeContent();
  }

  Future<void> _analyzeContent() async {
    debugPrint('📥 Analyserar delat innehåll...');

    // Simulera lite processing för bättre UX
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _detectionResult = _detector.detectContent(widget.content);
      _isProcessing = false;
    });

    // Auto-navigera för vissa typer
    _handleAutoNavigation();
  }

  void _handleAutoNavigation() {
    // Om det är ren recepttext, gå direkt till text import
    if (_detectionResult.type == ContentType.recipeText) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _navigateToTextImport();
        }
      });
    }
  }

  void _navigateToTextImport() {
    Navigator.pushReplacementNamed(
      context,
      '/franSocialaMedier',
      arguments: {
        'text': widget.content,
        'sourceUrl': _detectionResult.extractedUrl ?? 'Delad från annan app',
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importera recept')),
      body: _isProcessing ? _buildLoadingView() : _buildContentView(),
    );
  }

  Widget _buildLoadingView() {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const RecipeListSkeleton(itemCount: 1),
          SizedBox(height: AppTheme.spacingLg),
          Text('Analyserar innehåll...', style: AppTheme.subtitleStyle),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetectionHeader(),
          SizedBox(height: AppTheme.spacingLg),
          _buildContentPreview(),
          const Spacer(),
          _buildActionButtons(),
          SizedBox(height: AppTheme.spacingMd),
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
        color = AppTheme.primaryColor;
        break;
      case ContentType.recipeText:
        icon = Icons.restaurant_menu;
        title = 'Recepttext detekterad!';
        color = AppTheme.successColor;
        break;
      case ContentType.recipeUrl:
        icon = Icons.public;
        title = 'Receptlänk detekterad';
        color = AppTheme.primaryColor;
        break;
      default:
        icon = Icons.text_fields;
        title = 'Textinnehåll';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppTheme.smallRadius,
          ),
          child: Icon(icon, color: color, size: AppTheme.iconSizeAction),
        ),
        SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.sectionHeaderStyle),
              if (_detectionResult.extractedUrl != null) ...[
                SizedBox(height: AppTheme.spacingXxs),
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
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.mediumRadius,
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
        // För sociala medier - vi behöver WebView för att hämta receptet
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: AppTheme.mediumRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Vi kan snart hämta recept automatiskt från ${_getPlatformName()}!',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacingMd),
            Text(
              'Tills dess kan du:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(
              '1. Gå tillbaka till ${_getPlatformName()}\n'
              '2. Kopiera recepttexten från inlägget\n'
              '3. Kom tillbaka hit och klistra in',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: AppTheme.spacingLg),
            if (_detectionResult.extractedUrl != null)
              OutlinedButton.icon(
                onPressed: () {
                  // Gå till URL import som fallback
                  _navigateToUrlImport();
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Öppna i webbläsare'),
                style: AppTheme.secondaryButtonStyle,
              )
            else
              OutlinedButton.icon(
                onPressed: _navigateToTextImport,
                icon: const Icon(Icons.content_paste),
                label: const Text('Klistra in manuellt'),
                style: AppTheme.secondaryButtonStyle,
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
            SizedBox(height: AppTheme.spacingMd),
            ElevatedButton.icon(
              onPressed: _navigateToUrlImport,
              icon: const Icon(Icons.download),
              label: const Text('Hämta recept från webbsida'),
              style: AppTheme.primaryButtonStyle,
            ),
          ],
        );

      case ContentType.recipeText:
        // Ren recepttext - perfekt!
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successColor),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Recepttext detekterad! Vi kan importera detta.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacingMd),
            ElevatedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Fortsätt med import'),
              style: AppTheme.primaryButtonStyle,
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
            SizedBox(height: AppTheme.spacingMd),
            OutlinedButton.icon(
              onPressed: _navigateToTextImport,
              icon: const Icon(Icons.edit),
              label: const Text('Försök ändå'),
              style: AppTheme.secondaryButtonStyle,
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
