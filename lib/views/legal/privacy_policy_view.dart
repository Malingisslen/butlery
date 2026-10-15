import 'package:flutter/material.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/legal/legal_document.dart';
import 'package:butlery/widgets/legal/legal_link_foot.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/legal/legal_asset.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// GDPR Article 13/14 - Privacy Policy View
/// Displays the complete privacy policy, covering all GDPR
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
  String? _language;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language == _language) return;
    _language = language;
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

      final content = await loadLegalAsset('privacy_policy', _language!);

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
    return ButleryPage.undersida(
      title: context.l10n.privacyTitle,
      actions: [
        AppIconButton(
          icon: ButleryIcons.refreshCw,
          semanticLabel: context.l10n.privacyReload,
          onPressed: _isLoading ? null : _loadPrivacyPolicy,
        ),
      ],
      // The policy ships with the app, so it still opens offline, under the
      // offline banner.
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(child: _buildBody()),
        ],
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
    return LegalDocument(
      content: _policyContent!,
      webLinksEnabled: _isOnline,
      current: LegalDocumentKind.privacy,
    );
  }
}
