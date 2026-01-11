import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/widgets/common/layout_components.dart';

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
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final content =
          await rootBundle.loadString('assets/legal/privacy_policy_sv.md');

      if (mounted) {
        setState(() {
          _policyContent = content;
          _isLoading = false;
        });
      }

      app_logger.AppLogger.info(
          '[PrivacyPolicyView] Privacy policy loaded successfully');
    } catch (e) {
      app_logger.AppLogger.error(
          '[PrivacyPolicyView] Failed to load privacy policy', e);

      if (mounted) {
        setState(() {
          _errorMessage =
              'Kunde inte ladda integritetspolicyn. Försök igen senare.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integritetspolicy'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadPrivacyPolicy,
            tooltip: 'Ladda om',
          ),
        ],
      ),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Laddar integritetspolicy...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMedium,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
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
              label: const Text('Försök igen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.cardWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Ingen integritetspolicy tillgänglig',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textMedium,
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
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              _policyContent!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
          ),
        ),
        _buildContactButton(),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: AppDimensions.opacityVeryLight),
        border: Border(
          bottom: BorderSide(
            color: AppColors.info.withValues(alpha: AppDimensions.opacityMediumLight),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: AppDimensions.spacingL),
          Expanded(
            child: Text(
              'GDPR-kompatibel integritetspolicy. Senast uppdaterad: 2025-10-21',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.info,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundTint,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Har du frågor om vår integritetspolicy?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          ElevatedButton.icon(
            onPressed: _handleContactUs,
            icon: const Icon(Icons.email_rounded),
            label: const Text('Kontakta oss'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.cardWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleContactUs() async {
    final uri = Uri.parse('mailto:privacy@butlery.se?subject=Integritetsfråga');

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          _showError('Kunde inte öppna e-postklient');
        }
      }
    } catch (e) {
      app_logger.AppLogger.error(
          '[PrivacyPolicyView] Failed to launch email', e);
      if (mounted) {
        _showError('Kunde inte öppna e-postklient');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.cardWhite),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
