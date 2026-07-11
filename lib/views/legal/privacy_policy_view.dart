import 'package:flutter/material.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/legal/legal_contact_footer.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:butlery/core/extensions/localization_extension.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
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
      appBar: AdaptiveAppBar(
        title: context.l10n.privacyTitle,
        centerTitle: true,
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
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LoadingIndicator(),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.privacyLoading,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: cs.error,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            ElevatedButton.icon(
              onPressed: _loadPrivacyPolicy,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
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
            child: MarkdownBody(data: _policyContent!),
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
