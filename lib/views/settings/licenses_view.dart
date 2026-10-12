import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout/page_rule.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// OFL 1.1 condition 2 requires the copyright notice and licence to reach the
/// recipient of the font.
class LicensesView extends StatefulWidget {
  const LicensesView({super.key});

  static const noticesAsset = 'assets/fonts/THIRD_PARTY_NOTICES.txt';
  static const oflAsset = 'assets/fonts/OFL-1.1.txt';

  static const assets = [noticesAsset, oflAsset];

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
      appBar: ButleryTopBar.undersida(
        title: context.l10n.settingsLicensesTitle,
        backTo: context.l10n.settingsHelpTitle,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: SafeArea(
        child: ButleryPageBody(
          width: PageWidth.text,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return StateWidget.loading(message: context.l10n.loadingLicenses);
    }

    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ButleryIcon(
                ButleryIcons.triangleAlert,
                size: AppDimensions.iconSizeXXXl,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppDimensions.space16),
              Text(
                context.l10n.licensesCouldNotLoad,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.space24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const ButleryIcon(ButleryIcons.refreshCw),
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
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMarginOf(context),
        vertical: AppDimensions.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.licensesIntro,
            style: AppTextStyles.captionBase.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const AccentRule.inline(),
          for (var i = 0; i < texts.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimensions.space24),
            _document('${i + 1} · ${headings[i]}', texts[i]),
          ],
          // BUT-643: CC BY 4.0 attribution for the bundled nutrition table.
          const SizedBox(height: AppDimensions.space24),
          _document(
            '${texts.length + 1} · ${context.l10n.licensesLivsmedelsverketHeading}',
            context.l10n.licensesLivsmedelsverketBody,
          ),
          const SizedBox(height: AppDimensions.space24),
          // The packages' licences already live in Flutter's own page, so link
          // rather than duplicate them.
          ButleryListRow(
            leading: ButleryIcons.file,
            label: context.l10n.legalOpenSourceLicenses,
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
          child: Text(heading, style: AppTextStyles.titleLargeBold),
        ),
        const SizedBox(height: AppDimensions.space8),
        SelectableText(
          text,
          style: AppTextStyles.captionBase.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
