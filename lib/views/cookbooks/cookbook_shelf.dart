import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_detail_view.dart';
import 'package:butlery/views/cookbooks/cookbook_edit_sheet.dart';
import 'package:butlery/views/hem/hem_library_scroll.dart';
import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/cookbooks/cookbook_cover.dart';

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

    if (!vm.tagsLoaded && vm.error == null) {
      return HemLibraryScroll.boxBody(
        StateWidget.loading(message: l10n.cookbookLoading),
      );
    }
    if (vm.error != null && vm.cookbooks.isEmpty) {
      return HemLibraryScroll.boxBody(StateWidget.error(message: vm.error!));
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
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PersonalTagsView(),
                  ),
                ),
        ),
      );
    }

    final padding = AppDimensions.responsiveContentPadding(context);
    return HemLibraryScroll.sliverBody(
      key: shelfKey,
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: AppDimensions.spacingSm),
          sliver: SliverToBoxAdapter(
            child: Text(
              l10n.cookbookShelfCount(books.length),
              style: AppTextStyles.sectionLabel.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxBookWidth,
              childAspectRatio: bookAspectRatio,
              mainAxisSpacing: AppDimensions.spacingMd,
              crossAxisSpacing: AppDimensions.spacingMd,
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
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: cs.outline)),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingSm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ButleryIcon(ButleryIcons.plus, color: cs.onSurfaceVariant),
                    const SizedBox(height: AppDimensions.spacingXs),
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
  final tag = await showModalBottomSheet<PersonalTag>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(),
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
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Text(
                l10n.cookbookChooseTagTitle,
                style: AppTextStyles.titleLarge,
              ),
            ),
            if (tags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Text(l10n.cookbookAllTagsAreCookbooks),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final tag in tags)
                      ListTile(
                        leading: const ButleryIcon(ButleryIcons.tag),
                        title: Text(tag.name),
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
