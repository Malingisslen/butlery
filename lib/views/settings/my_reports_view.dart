import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/status_badge.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// "Mina rapporter" — surfaces user-submitted moderation reports + their
/// lifecycle status. Required by Google Play UGC appeal policy.
class MyReportsView extends StatefulWidget {
  const MyReportsView({super.key});

  @override
  State<MyReportsView> createState() => _MyReportsViewState();
}

class _MyReportsViewState extends State<MyReportsView> {
  late final MyReportsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<MyReportsViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.load();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MyReportsViewModel>.value(value: _vm),
      ],
      child: const _MyReportsContent(),
    );
  }
}

class _MyReportsContent extends StatelessWidget {
  const _MyReportsContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<MyReportsViewModel>();
    return BaseScaffold(
      title: l10n.myReportsTitle,
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, MyReportsViewModel vm) {
    if (vm.isLoading && !vm.hasReports) {
      return StateWidget.loading();
    }
    if (vm.hasError) {
      return StateWidget.error(
        message: context.l10n.myReportsLoadFailed,
        actionLabel: context.l10n.myReportsRetry,
        onAction: vm.refresh,
      );
    }
    if (!vm.hasReports) {
      return StateWidget.empty(
        title: context.l10n.myReportsEmpty,
        icon: Icons.flag_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacingSm,
        ),
        itemCount: vm.reports.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _ReportTile(report: vm.reports[i]),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final ContentReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeName = Localizations.localeOf(context).toLanguageTag();

    return ListTile(
      leading: Icon(_iconForType(report.contentType)),
      title: Text(
        report.reason,
        style: AppTextStyles.titleSmall,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        ContextualTimeFormatter.dateTime(report.createdAt.toLocal(),
            localeName: localeName),
        style: AppTextStyles.bodySmall,
      ),
      trailing: _StatusBadge(status: report.status, l10n: l10n),
    );
  }

  IconData _iconForType(ContentType type) {
    switch (type) {
      case ContentType.recipe:
        return Icons.restaurant_menu_outlined;
      case ContentType.comment:
        return Icons.chat_bubble_outline;
      case ContentType.message:
        return Icons.message_outlined;
      case ContentType.profile:
        return Icons.person_outline;
      case ContentType.cookSnap:
        return Icons.photo_camera_outlined;
      case ContentType.group:
        return Icons.group_outlined;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.l10n});

  final ReportStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = _resolve(cs, context.butleryColors.success);
    return StatusBadge(
      text: label,
      backgroundColor: color,
      textColor: cs.onPrimary,
    );
  }

  (String, Color) _resolve(ColorScheme cs, Color successColor) {
    switch (status) {
      case ReportStatus.newReport:
        return (l10n.myReportsStatusPending, cs.primary);
      case ReportStatus.inReview:
        return (l10n.myReportsStatusReviewed, cs.tertiary);
      case ReportStatus.actioned:
        return (l10n.myReportsStatusActioned, successColor);
      case ReportStatus.closed:
        return (l10n.myReportsStatusClosed, cs.outline);
    }
  }
}
