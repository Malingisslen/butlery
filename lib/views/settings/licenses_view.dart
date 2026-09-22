import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Shows the licence of every font the app bundles, as shipped.
///
/// OFL 1.1 condition 2 requires the copyright notice and licence to reach the
/// recipient of the font, so each document is rendered verbatim from the
/// bundle — never paraphrased or translated.
class LicensesView extends StatefulWidget {
  const LicensesView({super.key});

  static const noticesAsset = 'assets/fonts/THIRD_PARTY_NOTICES.txt';
  static const oflAsset = 'assets/fonts/OFL-1.1.txt';
  // The legacy families are still in pubspec `fonts:`, so they ship until the
  // legacy-removal package retires them — together with these two entries.
  static const josefinSansAsset = 'assets/fonts/JosefinSans-OFL.txt';
  static const spaceGroteskAsset = 'assets/fonts/SpaceGrotesk-OFL.txt';

  static const assets = [
    noticesAsset,
    oflAsset,
    josefinSansAsset,
    spaceGroteskAsset,
  ];

  @override
  State<LicensesView> createState() => _LicensesViewState();
}

class _LicensesViewState extends State<LicensesView> {
  List<String>? _texts;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      // cache: false because the bundle caches a FAILED load too, which
      // would make the retry button replay the same error forever.
      final texts = await Future.wait(
        LicensesView.assets.map((a) => rootBundle.loadString(a, cache: false)),
      );
      if (!mounted) return;
      setState(() {
        _texts = texts;
        _isLoading = false;
      });
    } catch (e) {
      app_logger.AppLogger.error(
        '[LicensesView] Failed to load licence documents',
        e,
      );
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.settingsLicensesTitle,
        centerTitle: true,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: SafeArea(
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
    if (_isLoading) return StateWidget.loading();

    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                context.l10n.licensesCouldNotLoad,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    final texts = _texts!;
    final headings = [
      context.l10n.licensesNoticesHeading,
      context.l10n.licensesOflHeading,
      'Josefin Sans',
      'Space Grotesk',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < texts.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimensions.spacingLg),
            _document(headings[i], texts[i]),
          ],
          const SizedBox(height: AppDimensions.spacingLg),
          // The fonts are the obligation this page exists for; the packages'
          // licences already live in Flutter's own page, so link rather than
          // duplicate them.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code),
            title: Text(context.l10n.legalOpenSourceLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'Butlery'),
          ),
        ],
      ),
    );
  }

  Widget _document(String heading, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(heading, style: AppTextStyles.titleMedium),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        SelectableText(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
