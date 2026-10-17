import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_detail_view.dart';
import 'package:butlery/views/cookbooks/cookbook_edit_sheet.dart';
import 'package:butlery/views/hem/hem_library_scroll.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/cookbooks/cookbook_cover.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// The Kokböcker half of Hem's library (BUT-1325): the user's cookbooks as
/// a shelf, and a tile that turns another tag into one.
class CookbookShelf extends StatelessWidget {
  const CookbookShelf({super.key});

  static const shelfKey = ValueKey('cookbook-shelf-scrollable');
  static const addTileKey = ValueKey('cookbook-shelf-add');

  /// A cover's width-to-height, a book standing up.
  static const double bookAspectRatio = 3 / 4;
  static const double maxBookWidth = 200;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CookbookViewModel>();
    final l10n = context.l10n;

    if (!vm.tagsLoaded && !vm.loadFailed) {
      return HemLibraryScroll.boxBody(
        StateWidget.loading(message: l10n.cookbookLoading),
      );
    }
    if (vm.loadFailed && vm.cookbooks.isEmpty) {
      return HemLibraryScroll.boxBody(
        StateWidget.error(
          message: vm.error ?? l10n.cookbookLoadFailed,
          onAction: vm.retryLoad,
          actionLabel: l10n.commonRetry,
        ),
      );
    }

    final books = vm.cookbooks;
    if (books.isEmpty) {
      return HemLibraryScroll.boxBody(
        StateWidget.empty(
          title: l10n.libraryTabCookbooks,
          subtitle: vm.hasAnyTags
              ? l10n.cookbookShelfEmpty
              : l10n.cookbookNoTags,
          icon: ButleryIcons.bookOpen,
          actionLabel: vm.hasAnyTags
              ? l10n.cookbookMakeFromTag
              : l10n.cookbookManageTags,
          onAction: vm.hasAnyTags
              ? () => showMakeCookbookFlow(context, vm)
              : () => Navigator.of(
                  context,
                ).pushNamed(Routes.settingsPersonalTags),
        ),
      );
    }

    final padding = AppDimensions.responsiveContentPadding(context);
    return HemLibraryScroll.sliverBody(
      key: shelfKey,
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: AppDimensions.space8),
          sliver: SliverToBoxAdapter(
            child: SectionHeading(l10n.cookbookShelfCount(books.length)),
          ),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxBookWidth,
              childAspectRatio: bookAspectRatio,
              mainAxisSpacing: AppDimensions.space16,
              crossAxisSpacing: AppDimensions.space16,
            ),
            delegate: SliverChildListDelegate([
              for (final book in books) _ShelfBook(tag: book),
              const _AddTile(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ShelfBook extends StatelessWidget {
  const _ShelfBook({required this.tag});

  final PersonalTag tag;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CookbookViewModel>();
    final count = vm.recipeCount(tag);
    return Semantics(
      button: true,
      label: context.l10n.a11yOpenCookbook,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: () => openCookbook(context, tag.id),
          child: CookbookCoverView(
            name: tag.name,
            cover: tag.cookbook!.cover,
            imageUrl: vm.coverImageUrl(tag),
            subtitle: context.l10n.cookbookRecipeCount(count),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          key: CookbookShelf.addTileKey,
          onTap: () =>
              showMakeCookbookFlow(context, context.read<CookbookViewModel>()),
          child: ButleryOutlinedBox(
            paintOnly: true,
            radius: AppDimensions.radiusSharp,
            borderColor: cs.outline,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.space8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ButleryIcon(ButleryIcons.plus, color: cs.onSurfaceVariant),
                    const SizedBox(height: AppDimensions.space4),
                    Text(
                      context.l10n.cookbookMakeFromTag,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void openCookbook(BuildContext context, String tagId) {
  final vm = context.read<CookbookViewModel>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<CookbookViewModel>.value(
        value: vm,
        child: CookbookDetailView(tagId: tagId),
      ),
    ),
  );
}

/// Pick a tag, then fill in the cookbook sheet for it.
Future<void> showMakeCookbookFlow(
  BuildContext context,
  CookbookViewModel vm,
) async {
  final tag = await showButlerySheet<PersonalTag>(
    context: context,
    builder: (sheetContext) => ChangeNotifierProvider<CookbookViewModel>.value(
      value: vm,
      child: const _TagChooser(),
    ),
  );
  if (tag == null || !context.mounted) return;
  final made = await showCookbookEditSheet(context, vm: vm, tag: tag);
  if (made && context.mounted) openCookbook(context, tag.id);
}

class _TagChooser extends StatelessWidget {
  const _TagChooser();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CookbookViewModel>();
    final tags = vm.otherTags;
    final l10n = context.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: Text(
                l10n.cookbookChooseTagTitle,
                style: AppTextStyles.titleLarge,
              ),
            ),
            if (tags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.space16),
                child: Text(l10n.cookbookAllTagsAreCookbooks),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final tag in tags)
                      ButleryItemRow(
                        leadingIcon: ButleryIcons.tag,
                        title: tag.name,
                        onTap: () => Navigator.of(context).pop(tag),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
