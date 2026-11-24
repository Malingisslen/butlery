import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/cook_history_viewmodel.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Mer › Lagade recept: every cook, newest first, with the recipes cooked
/// most often on top.
class CookHistoryView extends StatefulWidget {
  const CookHistoryView({super.key});

  @override
  State<CookHistoryView> createState() => _CookHistoryViewState();
}

class _CookHistoryViewState extends State<CookHistoryView> {
  late final CookHistoryViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CookHistoryViewModel()..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CookHistoryViewModel>.value(
      value: _vm,
      child: const _CookHistoryContent(),
    );
  }
}

class _CookHistoryContent extends StatelessWidget {
  const _CookHistoryContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<CookHistoryViewModel>();

    if (vm.isLoading) {
      return MoreAreaScaffold(
        title: l10n.cookHistoryTitle,
        sections: [StateWidget.loading(message: l10n.loadingRecipes)],
      );
    }
    if (vm.hasFailed && vm.entries.isEmpty) {
      return MoreAreaScaffold(
        title: l10n.cookHistoryTitle,
        sections: [
          StateWidget.error(
            message: l10n.cookHistoryLoadError,
            actionLabel: l10n.cookHistoryRetry,
            onAction: vm.load,
          ),
        ],
      );
    }

    final entries = vm.entries;
    final frequent = vm.frequent;
    final locale = l10n.localeName;
    final shortDate = DateFormat.MMMd(locale);
    final monthFormat = DateFormat.yMMMM(locale);

    // The list arrives newest first, so one pass groups it by month.
    final months = <String, List<CookHistoryEntry>>{};
    for (final e in entries) {
      months.putIfAbsent(monthFormat.format(e.event.cookedAt), () => []).add(e);
    }

    return MoreAreaScaffold(
      title: l10n.cookHistoryTitle,
      sections: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space8),
          child: Wrap(
            spacing: AppDimensions.space8,
            children: [
              for (final f in CookHistoryFilter.values)
                ButleryFilterChip(
                  label: _filterLabel(l10n, f),
                  selected: vm.filter == f,
                  onSelected: (_) => vm.setFilter(f),
                ),
            ],
          ),
        ),
        if (vm.entries.isEmpty && vm.filter == CookHistoryFilter.all)
          StateWidget.empty(
            title: l10n.cookHistoryEmptyTitle,
            subtitle: l10n.cookHistoryEmptyBody,
          )
        else ...[
          if (frequent.isNotEmpty && vm.filter == CookHistoryFilter.all)
            ButleryListSection(
              title: l10n.cookHistoryFrequent,
              rows: [
                for (final r in frequent)
                  ButleryListRow.note(
                    label: r.title,
                    subtitle: l10n.cookHistoryFrequentSubtitle(
                      r.cookCount,
                      r.lastCookedAt == null
                          ? ''
                          : shortDate.format(r.lastCookedAt!),
                    ),
                  ),
              ],
            ),
          for (final month in months.entries)
            ButleryListSection(
              title: month.key,
              rows: [
                for (final e in month.value)
                  ButleryListRow.note(
                    label: e.title ?? l10n.cookHistoryUnknownRecipe,
                    subtitle: _subtitle(l10n, e, shortDate),
                  ),
              ],
            ),
          if (vm.hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.space16,
              ),
              child: ActionButtons.outlinedButton(
                context,
                label: l10n.cookHistoryLoadMore,
                onPressed: vm.isLoadingMore ? null : vm.loadMore,
                isExpanded: true,
              ),
            ),
        ],
      ],
    );
  }

  static String _filterLabel(AppLocalizations l10n, CookHistoryFilter f) {
    switch (f) {
      case CookHistoryFilter.all:
        return l10n.cookHistoryFilterAll;
      case CookHistoryFilter.favorites:
        return l10n.cookHistoryFilterFavorites;
      case CookHistoryFilter.lastMonth:
        return l10n.cookHistoryFilterMonth;
    }
  }

  static String _rating(num rating, String locale) =>
      NumberFormat('0.#', locale).format(rating);

  static String _subtitle(
    AppLocalizations l10n,
    CookHistoryEntry e,
    DateFormat date,
  ) {
    final rating = e.rating;
    final head = rating == null
        ? date.format(e.event.cookedAt)
        : l10n.cookHistoryEventRated(
            date.format(e.event.cookedAt),
            _rating(rating, l10n.localeName),
          );
    final note = e.event.note;
    return note == null ? head : '$head\n„$note”';
  }
}
