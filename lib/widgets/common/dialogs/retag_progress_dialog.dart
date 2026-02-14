import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
          content: Text('$count recept omtaggade'),
          backgroundColor: AppColors.success,
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
      title: const Row(
        children: [
          Icon(
            Icons.sync,
            color: AppColors.forestGreen,
            size: AppDimensions.iconSizeL,
          ),
          SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text('Omtaggar recept'),
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
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
          ] else ...[
            if (_total > 0)
              Text(
                'Omtaggar $_current av $_total recept...',
                style: AppTextStyles.bodyMedium,
              )
            else
              Text(
                'Hämtar recept...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            const SizedBox(height: AppDimensions.spacingMd),
            LinearProgressIndicator(
              value: _total > 0 ? _current / _total : null,
              backgroundColor: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityVeryLight),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
            ),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stäng'),
          )
        else
          TextButton(
            onPressed: _isRunning
                ? () {
                    setState(() => _cancelled = true);
                    Navigator.of(context).pop();
                  }
                : null,
            child: const Text('Avbryt'),
          ),
      ],
    );
  }
}
