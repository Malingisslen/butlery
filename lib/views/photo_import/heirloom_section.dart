// lib/views/photo_import/heirloom_section.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// BUT-410 heirloom toggle + metadata form.
///
/// Visible whenever an image is loaded. Toggle on → reveals three form
/// fields (writer / year / note) bound directly to [PhotoImportViewModel]'s
/// heirloom state. Shows an offline banner when [PhotoImportViewModel.isOfflineQueued]
/// is set after a failed upload attempt.
class HeirloomSection extends StatefulWidget {
  final PhotoImportViewModel viewModel;

  const HeirloomSection({super.key, required this.viewModel});

  @override
  State<HeirloomSection> createState() => _HeirloomSectionState();
}

class _HeirloomSectionState extends State<HeirloomSection> {
  late final TextEditingController _writerCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _writerCtrl = TextEditingController(
      text: widget.viewModel.heirloomWriterName,
    );
    _yearCtrl = TextEditingController(
      text: (widget.viewModel.heirloomYear?.toString()).orEmpty(),
    );
    _noteCtrl = TextEditingController(text: widget.viewModel.heirloomNote);
  }

  @override
  void dispose() {
    _writerCtrl.dispose();
    _yearCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = widget.viewModel;
    final currentYear = clock.now().year;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.l10n.heirloomToggle,
              style: AppTextStyles.titleSmall,
            ),
            value: vm.isHeirloom,
            onChanged: (v) => vm.isHeirloom = v,
          ),
          if (vm.isHeirloom) ...[
            const SizedBox(height: AppDimensions.space4),
            if (vm.isOfflineQueued)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: context.modeColors.warning.withValues(
                    alpha: AppDimensions.opacityVeryLight,
                  ),
                  border: Border.all(
                    color: context.modeColors.warning.withValues(
                      alpha: AppDimensions.opacityMediumLight,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    ButleryIcon(
                      ButleryIcons.wifiOff,
                      color: context.modeColors.warning,
                      size: AppDimensions.iconSizeM,
                    ),
                    const SizedBox(width: AppDimensions.space4),
                    Expanded(
                      child: Text(
                        context.l10n.heirloomUploadOffline,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.modeColors.onWarningContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _writerCtrl,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: context.l10n.heirloomWriterLabel,
              ),
              onChanged: (v) => vm.heirloomWriterName = v,
            ),
            const SizedBox(height: AppDimensions.space4),
            TextField(
              controller: _yearCtrl,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: context.l10n.heirloomYearLabel,
              ),
              onChanged: (v) {
                // Silently clear out-of-range — HeirloomMetadata's ctor
                // would throw otherwise, and we don't want to block typing.
                final parsed = int.tryParse(v);
                vm.heirloomYear =
                    (parsed == null || parsed < 1800 || parsed > currentYear)
                    ? null
                    : parsed;
              },
            ),
            const SizedBox(height: AppDimensions.space4),
            TextField(
              controller: _noteCtrl,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.heirloomNoteLabel,
              ),
              onChanged: (v) => vm.heirloomNote = v,
            ),
          ],
        ],
      ),
    );
  }
}
