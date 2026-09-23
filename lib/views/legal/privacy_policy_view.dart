import 'package:flutter/material.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/legal/legal_contact_footer.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline_service.dart';

/// GDPR Article 13/14 - Privacy Policy View
/// Displays the complete privacy policy in Swedish, covering all GDPR
/// transparency and information requirements.
/// **Features:**
/// - Text-formatted privacy policy
/// - Clickable links for external resources
/// - Easy navigation and readability
/// - GDPR Article 13/14 compliant
class PrivacyPolicyView extends StatefulWidget {
  const PrivacyPolicyView({super.key});

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
  String? _policyContent;
  bool _isLoading = true;
  String? _errorMessage;

  /// Null when no offline service is registered; the page then treats the
  /// device as online.
  OfflineService? _offlineService;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _offlineService = ServiceLocator.tryGet<OfflineService>();
    _offlineService?.addListener(_onConnectivityChanged);
    _isOnline = _offlineService?.isOnline ?? true;
    _loadPrivacyPolicy();
  }

  @override
  void dispose() {
    _offlineService?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    final isOnline = _offlineService?.isOnline ?? true;
    if (!mounted || isOnline == _isOnline) return;
    setState(() => _isOnline = isOnline);
  }

  Future<void> _loadPrivacyPolicy() async {
    if (!mounted) return;
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final lang = PlatformDispatcher.instance.locale.languageCode;
      final assetPath = 'assets/legal/privacy_policy_$lang.md';

      String content;
      try {
        content = await rootBundle.loadString(assetPath);
      } catch (_) {
        // Fallback to Swedish
        content = await rootBundle.loadString(
          'assets/legal/privacy_policy_sv.md',
        );
      }

      if (mounted) {
        setState(() {
          _policyContent = content;
          _isLoading = false;
        });
      }

      app_logger.AppLogger.info(
        '[PrivacyPolicyView] Privacy policy loaded successfully',
      );
    } catch (e) {
      app_logger.AppLogger.error(
        '[PrivacyPolicyView] Failed to load privacy policy',
        e,
      );

      if (mounted) {
        setState(() {
          _errorMessage = context.l10n.privacyCouldNotLoad;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: context.l10n.privacyTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadPrivacyPolicy,
            tooltip: context.l10n.privacyReload,
          ),
        ],
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: SafeArea(
        // The policy ships with the app, so it still opens offline, under the
        // offline banner (produktregler.md:162; P5-U30).
        child: Column(
          children: [
            LayoutComponents.offlineIndicator(),
            Expanded(
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
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_policyContent == null) {
      return _buildEmptyState();
    }

    return _buildPolicyContent();
  }

  Widget _buildLoadingState() {
    // Plate line + what is being fetched (produktregler.md:163, B-18).
    return StateWidget.loading(message: context.l10n.privacyLoading);
  }

  Widget _buildErrorState() {
    // The standard error state names the document and offers Försök igen
    // (content-style-guide.md:87-95; state_widget.dart default action).
    return StateWidget.error(
      message: _errorMessage!,
      onAction: _loadPrivacyPolicy,
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        context.l10n.privacyNotAvailable,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildPolicyContent() {
    return Column(
      children: [
        _buildInfoBanner(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingXl),
            // Offline, web links cannot open, so they turn inactive and
            // say why (Grafisk manual v6:665 'åtgärder som kräver nät blir
            // inaktiva med förklarande text').
            child: MarkdownBody(
              data: _policyContent!,
              webLinksEnabled: _isOnline,
            ),
          ),
        ),
        const LegalContactFooter(),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: context.butleryColors.info.withValues(
          alpha: AppDimensions.opacityVeryLight,
        ),
        border: Border(
          bottom: BorderSide(
            color: context.butleryColors.info.withValues(
              alpha: AppDimensions.opacityMediumLight,
            ),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: context.butleryColors.info,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingL),
          Expanded(
            child: Text(
              context.l10n.privacyGdprCompliant,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.butleryColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
