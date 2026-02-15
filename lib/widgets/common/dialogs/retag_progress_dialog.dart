import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Progress dialog for batch retagging all user recipes.
///
/// Shows a linear progress bar with current/total counts and a cancel button.
/// Auto-closes on completion with a success snackbar showing the result count.
class RetagProgressDialog extends StatefulWidget {
  /// The retag function to execute. Receives an onProgress callback
  /// and returns the number of recipes successfully retagged.
  final Future<int> Function(void Function(int current, int total) onProgress)
      retagFunction;

  const RetagProgressDialog({super.key, required this.retagFunction});

  @override
  State<RetagProgressDialog> createState() => _RetagProgressDialogState();
}

class _RetagProgressDialogState extends State<RetagProgressDialog> {
  int _current = 0;
  int _total = 0;
  bool _cancelled = false;
  bool _isRunning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startRetag();
  }

  Future<void> _startRetag() async {
    setState(() => _isRunning = true);

    try {
      final count = await widget.retagFunction((current, total) {
        if (!mounted || _cancelled) return;
        setState(() {
          _current = current;
          _total = total;
        });
      });

      if (!mounted) return;

      // Auto-close and show result
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.retagRecipesRetagged(count)),
          backgroundColor: context.butleryColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(),
      title: Row(
        children: [
          Icon(
            Icons.sync,
            color: Theme.of(context).colorScheme.primary,
            size: AppDimensions.iconSizeL,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(context.l10n.retagRetaggingRecipes),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
          ] else ...[
            if (_total > 0)
              Text(
                context.l10n.retagRetaggingProgress(_current, _total),
                style: AppTextStyles.bodyMedium,
              )
            else
              Text(
                context.l10n.retagFetchingRecipes,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppDimensions.spacingMd),
            LinearProgressIndicator(
              value: _total > 0 ? _current / _total : null,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: AppDimensions.opacityVeryLight),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary),
            ),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonClose),
          )
        else
          TextButton(
            onPressed: _isRunning
                ? () {
                    setState(() => _cancelled = true);
                    Navigator.of(context).pop();
                  }
                : null,
            child: Text(context.l10n.commonCancel),
          ),
      ],
    );
  }
}
