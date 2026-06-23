// lib/views/photo_import/photo_page_strip.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/overlay_button.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// BUT-903: horizontal strip of the photos combined into one recipe.
///
/// Shows each captured page as a thumbnail (drag to reorder — order is the OCR
/// concatenation order), a remove button per page, and an "add page" tile while
/// under the [PhotoImportViewModel.maxPages] cap. Hidden entirely until at least
/// one image exists, and the reorder hint only surfaces with 2+ pages so the
/// single-photo flow stays visually unchanged.
class PhotoPageStrip extends StatelessWidget {
  final PhotoImportViewModel viewModel;

  const PhotoPageStrip({super.key, required this.viewModel});

  static const double _thumbSize = 96;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pages = viewModel.pageImages;
    if (pages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (viewModel.hasMultiplePages) ...[
          Text(
            context.l10n.importPhotoPagesCombined(viewModel.pageCount),
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimensions.spacingS),
        ],
        SizedBox(
          height: _thumbSize + 28,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: viewModel.hasMultiplePages,
            itemCount: pages.length,
            onReorder: viewModel.reorderPage,
            footer: viewModel.canAddPage
                ? Padding(
                    key: const ValueKey('photo-page-add'),
                    padding: const EdgeInsets.only(
                      left: AppDimensions.spacingS,
                    ),
                    child: _AddPageTile(
                      size: _thumbSize,
                      onPressed: viewModel.isProcessing
                          ? null
                          : () => _showAddPageSource(context),
                    ),
                  )
                : null,
            itemBuilder: (context, index) {
              return Padding(
                key: ValueKey('photo-page-$index'),
                padding: const EdgeInsets.only(right: AppDimensions.spacingS),
                child: _PageThumbnail(
                  bytes: pages[index],
                  pageNumber: index + 1,
                  size: _thumbSize,
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                title: Text(sheetContext.l10n.importTakePhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  viewModel.addPageFromCamera();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                title: Text(sheetContext.l10n.importChooseFromGallery),
                onTap: () {
                  Navigator.pop(sheetContext);
                  viewModel.addPageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageThumbnail extends StatelessWidget {
  final Uint8List bytes;
  final int pageNumber;
  final double size;
  final VoidCallback? onRemove;

  const _PageThumbnail({
    required this.bytes,
    required this.pageNumber,
    required this.size,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              child: Image.memory(
                bytes,
                height: size,
                width: size,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: AppDimensions.spacingXxs,
              right: AppDimensions.spacingXxs,
              child: Semantics(
                label: context.l10n.a11yRemovePhotoPage(pageNumber),
                button: true,
                child: OverlayButton.remove(
                  onPressed: onRemove,
                  tooltip: context.l10n.a11yRemovePhotoPage(pageNumber),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          context.l10n.importPhotoPageLabel(pageNumber),
          style: AppTextStyles.badgeLarge.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AddPageTile extends StatelessWidget {
  final double size;
  final VoidCallback? onPressed;

  const _AddPageTile({required this.size, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.importPhotoAddPage,
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(
              color: onPressed == null ? cs.outlineVariant : cs.primary,
              width: AppDimensions.borderWidthStandard,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                color: onPressed == null ? cs.outlineVariant : cs.primary,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(height: AppDimensions.spacingXxs),
              Text(
                context.l10n.importPhotoAddPage,
                textAlign: TextAlign.center,
                style: AppTextStyles.badgeLarge.copyWith(
                  color: onPressed == null ? cs.outlineVariant : cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
