import 'package:flutter/material.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/legal/legal_document.dart';
import 'package:butlery/widgets/legal/legal_link_foot.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/legal/legal_asset.dart';

class CommunityGuidelinesView extends StatefulWidget {
  const CommunityGuidelinesView({super.key});

  @override
  State<CommunityGuidelinesView> createState() =>
      _CommunityGuidelinesViewState();
}

class _CommunityGuidelinesViewState extends State<CommunityGuidelinesView> {
  String? _content;
  bool _isLoading = true;
  String? _errorMessage;
  String? _language;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language == _language) return;
    _language = language;
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final content = await loadLegalAsset('community_guidelines', _language!);

      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      app_logger.AppLogger.error(
        '[CommunityGuidelinesView] Failed to load community guidelines',
        e,
      );

      if (mounted) {
        setState(() {
          _errorMessage = context.l10n.legalGuidelinesCouldNotLoad;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ButleryPage.undersida(
      title: context.l10n.legalCommunityGuidelinesTitle,
      // The document ships with the app, so it still opens offline, under
      // the offline banner.
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
      return StateWidget.loading(
        message: context.l10n.loadingCommunityGuidelines,
      );
    }

    if (_errorMessage != null) {
      // The standard error state names the document and offers Försök igen
      // (content-style-guide.md:87-95; state_widget.dart default action).
      return StateWidget.error(message: _errorMessage!, onAction: _loadContent);
    }

    if (_content == null) return const SizedBox.shrink();

    return LegalDocument(
      content: _content!,
      current: LegalDocumentKind.guidelines,
    );
  }
}
