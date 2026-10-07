import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// The draft state in the recipe editor's top bar.
///
/// BUT-2224 = A: a failed draft write shows a warning triangle instead of
/// the cloud, and the failure snackbar once per failure period — a period
/// starts with a failed write and ends with the next successful one.
class DraftSaveIndicator extends StatefulWidget {
  const DraftSaveIndicator({
    super.key,
    required this.isSaving,
    required this.hasRecentSave,
    required this.hasFailed,
    required this.failurePeriod,
    this.color,
  });

  final bool isSaving;
  final bool hasRecentSave;
  final bool hasFailed;

  /// Grows by one each time a failure period starts.
  final int failurePeriod;
  final Color? color;

  @override
  State<DraftSaveIndicator> createState() => _DraftSaveIndicatorState();
}

class _DraftSaveIndicatorState extends State<DraftSaveIndicator> {
  int _announcedPeriod = 0;

  @override
  void initState() {
    super.initState();
    _announceIfNewPeriod();
  }

  @override
  void didUpdateWidget(DraftSaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _announceIfNewPeriod();
  }

  void _announceIfNewPeriod() {
    if (!widget.hasFailed || widget.failurePeriod <= _announcedPeriod) return;
    _announcedPeriod = widget.failurePeriod;
    // A snackbar cannot be shown during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = context.l10n;
      SnackBarUtils.showFailure(
        context,
        what: l10n.autoSaveFailed,
        preserved: l10n.autoSaveFailedPreserved,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSaving) {
      return SizedBox(
        width: AppDimensions.iconSizeL,
        child: PlateLine(semanticLabel: context.l10n.statusSaving),
      );
    }
    if (widget.hasFailed) {
      return ButleryIcon(
        ButleryIcons.triangleAlert,
        key: const ValueKey('draft-save-failed'),
        size: AppDimensions.iconSizeM,
        color: AppModeColors.textWarning(Theme.of(context).brightness),
        semanticLabel: context.l10n.autoSaveFailed,
      );
    }
    if (widget.hasRecentSave) {
      return ButleryIcon(
        Icons.cloud_done_outlined,
        size: AppDimensions.iconSizeM,
        color: widget.color,
      );
    }
    return const SizedBox.shrink();
  }
}
