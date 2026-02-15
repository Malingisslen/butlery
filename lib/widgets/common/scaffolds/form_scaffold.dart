import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';

/// Form scaffold consolidating patterns from 18+ files
class FormScaffold extends StatelessWidget {
  final String? title;
  final Widget form;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool showSaveButton;
  final bool showCancelButton;
  final bool isLoading;
  final bool showBackButton;
  final List<Widget>? additionalActions;

  const FormScaffold({
    super.key,
    this.title,
    required this.form,
    this.onSave,
    this.onCancel,
    this.showSaveButton = true,
    this.showCancelButton = false,
    this.isLoading = false,
    this.showBackButton = true,
    this.additionalActions,
  });

  @override
  Widget build(BuildContext context) {
    final padding = AppDimensions.responsiveContentPadding(context);
    final maxFormWidth = Breakpoints.getMaxFormWidth(context);

    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: _buildActions(context),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFormWidth),
                child: SingleChildScrollView(
                  padding: padding,
                  child: form,
                ),
              ),
            ),
          ),
          if (showSaveButton || showCancelButton) _buildBottomButtons(context),
        ],
      ),
    );
  }

  List<Widget>? _buildActions(BuildContext context) {
    final actions = <Widget>[];
    if (additionalActions != null) {
      actions.addAll(additionalActions!);
    }
    if (showSaveButton && onSave != null) {
      actions.add(
        IconButton(
          onPressed: isLoading ? null : onSave,
          icon: isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          tooltip: context.l10n.commonSave,
        ),
      );
    }
    return actions.isEmpty ? null : actions;
  }

  Widget _buildBottomButtons(BuildContext context) {
    final padding = AppDimensions.responsiveContentPadding(context);
    final maxFormWidth = Breakpoints.getMaxFormWidth(context);
    final buttonSpacing = Breakpoints.valueFor(
      context: context,
      mobile: AppDimensions.spacingMd,
      tablet: AppDimensions.spacingLg,
      desktop: AppDimensions.spacingLg,
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxFormWidth),
          child: Row(
            children: [
              if (showCancelButton) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : (onCancel ?? () => Navigator.pop(context)),
                    child: Text(context.l10n.commonCancel),
                  ),
                ),
                if (showSaveButton) SizedBox(width: buttonSpacing),
              ],
              if (showSaveButton) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSave,
                    child: isLoading
                        ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest),
                            ),
                          )
                        : Text(context.l10n.commonSave),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
