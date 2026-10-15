// lib/views/photo_import/photo_page_strip.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/overlay_button.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// BUT-903: horizontal strip of the photos combined into one recipe.
///
/// Shows each captured page as a numbered thumbnail (drag to reorder — order is
/// the OCR concatenation order), a remove button per page, and an "add page"
/// tile while under the [PhotoImportViewModel.maxPages] cap. Hidden entirely
/// until at least one image exists.
class PhotoPageStrip extends StatelessWidget {
  final PhotoImportViewModel viewModel;

  const PhotoPageStrip({super.key, required this.viewModel});

  static const double _thumbWidth = 88;
  static const double _thumbHeight = 112;

  @override
  Widget build(BuildContext context) {
    final pages = viewModel.pageImages;
    if (pages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          context.l10n.importPhotoPagesHeading(viewModel.pageCount),
        ),
        const SizedBox(height: AppDimensions.space8),
        SizedBox(
          height: _thumbHeight,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: viewModel.hasMultiplePages,
            itemCount: pages.length,
            onReorder: viewModel.reorderPage,
            // BUT-684: handwritten mode is a single-image, different-pipeline
            // flow — hide the add-page tile so the affordance can't offer an
            // append that would replace the handwritten capture instead.
            footer: viewModel.canAddPage && !viewModel.isHandwritten
                ? Padding(
                    key: const ValueKey('photo-page-add'),
                    padding: const EdgeInsetsDirectional.only(
                      start: AppDimensions.space4,
                    ),
                    child: _AddPageTile(
                      width: _thumbWidth,
                      height: _thumbHeight,
                      onPressed: viewModel.isProcessing
                          ? null
                          : () => _showAddPageSource(context),
                    ),
                  )
                : null,
            itemBuilder: (context, index) {
              return Padding(
                key: ValueKey('photo-page-$index'),
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.space4,
                ),
                child: _PageThumbnail(
                  bytes: pages[index],
                  pageNumber: index + 1,
                  width: _thumbWidth,
                  height: _thumbHeight,
                  onRemove: viewModel.isProcessing
                      ? null
                      : () => viewModel.removePage(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddPageSource(BuildContext context) {
    showButleryListSheet<void>(
      context,
      title: context.l10n.importPhotoAddPage,
      rows: (sheetContext) => [
        ButleryListRow(
          leading: ButleryIcons.camera,
          label: sheetContext.l10n.importTakePhoto,
          onTap: () {
            Navigator.pop(sheetContext);
            viewModel.addPageFromCamera();
          },
        ),
        ButleryListRow(
          leading: ButleryIcons.image,
          label: sheetContext.l10n.importChooseFromGallery,
          onTap: () {
            Navigator.pop(sheetContext);
            viewModel.addPageFromGallery();
          },
        ),
      ],
    );
  }
}

class _PageThumbnail extends StatelessWidget {
  final Uint8List bytes;
  final int pageNumber;
  final double width;
  final double height;
  final VoidCallback? onRemove;

  const _PageThumbnail({
    required this.bytes,
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: cs.secondaryContainer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.cover),
              Positioned(
                top: AppDimensions.space4,
                right: AppDimensions.space4,
                child: Semantics(
                  label: context.l10n.a11yRemovePhotoPage(pageNumber),
                  button: true,
                  child: OverlayButton.remove(
                    onPressed: onRemove,
                    tooltip: context.l10n.a11yRemovePhotoPage(pageNumber),
                  ),
                ),
              ),
              Positioned(
                left: AppDimensions.space8,
                bottom: AppDimensions.space4,
                child: Text(
                  context.l10n.importPhotoPageLabel(pageNumber),
                  style: AppTextStyles.badgeLarge.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPageTile extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback? onPressed;

  const _AddPageTile({
    required this.width,
    required this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = onPressed == null ? cs.outlineVariant : cs.onSurfaceVariant;
    return Semantics(
      label: context.l10n.importPhotoAddPage,
      button: true,
      excludeSemantics: true,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          child: ButleryOutlinedBox(
            height: height,
            width: width,
            borderColor: color,
            radius: AppDimensions.radiusControl,
            child: Center(
              child: ButleryIcon(ButleryIcons.plus, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
