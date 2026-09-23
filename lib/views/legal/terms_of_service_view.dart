import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/legal/legal_contact_footer.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:butlery/core/extensions/localization_extension.dart';

class TermsOfServiceView extends StatefulWidget {
  const TermsOfServiceView({super.key});

  @override
  State<TermsOfServiceView> createState() => _TermsOfServiceViewState();
}

class _TermsOfServiceViewState extends State<TermsOfServiceView> {
  String? _content;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final lang = PlatformDispatcher.instance.locale.languageCode;
      final assetPath = 'assets/legal/terms_of_service_$lang.md';

      String content;
      try {
        content = await rootBundle.loadString(assetPath);
      } catch (_) {
        // Fallback to Swedish
        content = await rootBundle.loadString(
          'assets/legal/terms_of_service_sv.md',
        );
      }

      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      app_logger.AppLogger.error(
        '[TermsOfServiceView] Failed to load terms of service',
        e,
      );

      if (mounted) {
        setState(() {
          _errorMessage = context.l10n.legalTermsCouldNotLoad;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: context.l10n.legalTermsOfService,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: SafeArea(
        // The document ships with the app, so it still opens offline, under
        // the offline banner (produktregler.md:162; P5-U30).
        child: Column(
          children: [
            LayoutComponents.offlineIndicator(),
            Expanded(
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
      return StateWidget.loading(message: context.l10n.loadingTerms);
    }

    if (_errorMessage != null) {
      // The standard error state names the document and offers Försök igen
      // (content-style-guide.md:87-95; state_widget.dart default action).
      return StateWidget.error(message: _errorMessage!, onAction: _loadContent);
    }

    if (_content == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingXl),
            child: SelectableText(
              _content!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
            ),
          ),
        ),
        const LegalContactFooter(),
      ],
    );
  }
}
