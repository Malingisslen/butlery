/// Base Dialog Classes - Unified dialog patterns with template method pattern for form, confirmation, and loading dialogs.
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// Base dialog using template method pattern - provides unified scaffold with title, content, actions, loading/error states.
abstract class BaseDialog<T> extends StatefulWidget {
  final String title;
  final IconData? titleIcon;
  final String? subtitle;
  final String? primaryActionText;
  final String? secondaryActionText;
  final IconData? primaryActionIcon;
  final Color? primaryActionColor;
  final bool isDangerous;
  final bool barrierDismissible;

  const BaseDialog({
    super.key,
    required this.title,
    this.titleIcon,
    this.subtitle,
    this.primaryActionText,
    this.secondaryActionText,
    this.primaryActionIcon,
    this.primaryActionColor,
    this.isDangerous = false,
    this.barrierDismissible = true,
  });

  Widget buildContent(BuildContext context);
  Future<T?> performAction(BuildContext context);
  bool validateBeforeAction() => true;
  Widget? buildAdditionalContent(BuildContext context) => null;

  @override
  State<BaseDialog<T>> createState() => _BaseDialogState<T>();
}

class _BaseDialogState<T> extends State<BaseDialog<T>> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: widget.titleIcon != null
          ? Icon(
              widget.titleIcon!,
              color: widget.isDangerous
                  ? cs.error
                  : widget.primaryActionColor ?? cs.primary,
              size: AppDimensions.iconSizeXxl,
            )
          : null,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(widget.subtitle!, style: AppTextStyles.bodyMediumMuted),
            const SizedBox(height: AppDimensions.spacingM),
          ],
          widget.buildContent(context),
          if (widget.buildAdditionalContent(context) != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            widget.buildAdditionalContent(context)!,
          ],
          if (_error != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _buildErrorDisplay(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(widget.secondaryActionText ?? context.l10n.commonCancel),
        ),
        _buildPrimaryButton(),
      ],
    );
  }

  String _resolvedPrimaryActionText() {
    if (widget.primaryActionText != null) return widget.primaryActionText!;
    if (widget.isDangerous) return context.l10n.commonDelete;
    if (widget is BaseFormDialog) return context.l10n.commonSave;
    return 'OK';
  }

  Widget _buildPrimaryButton() {
    final cs = Theme.of(context).colorScheme;
    final buttonColor = widget.isDangerous
        ? cs.error
        : (widget.primaryActionColor ?? cs.primary);
    final resolvedText = _resolvedPrimaryActionText();
    if (widget.isDangerous) {
      return FilledButton.icon(
        onPressed: _isLoading ? null : _onPrimaryAction,
        style: FilledButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: cs.surfaceContainerHighest,
        ),
        icon: _isLoading
            ? LoadingIndicator(
                size: 16,
                strokeWidth: 2,
                color: cs.surfaceContainerHighest,
              )
            : Icon(widget.primaryActionIcon ?? Icons.delete),
        label: Text(_isLoading ? context.l10n.commonWorking : resolvedText),
      );
    } else {
      return FilledButton.icon(
        onPressed: _isLoading ? null : _onPrimaryAction,
        style: FilledButton.styleFrom(backgroundColor: buttonColor),
        icon: _isLoading
            ? LoadingIndicator(
                size: 16,
                strokeWidth: 2,
                color: cs.surfaceContainerHighest,
              )
            : Icon(widget.primaryActionIcon ?? Icons.check),
        label: Text(_isLoading ? context.l10n.commonWorking : resolvedText),
      );
    }
  }

  Future<void> _onPrimaryAction() async {
    if (!widget.validateBeforeAction()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.performAction(context);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Dialog action failed: $e', stackTrace);
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildErrorDisplay() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        border: Border.all(color: cs.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Base form dialog extending BaseDialog with form validation and field management.
abstract class BaseFormDialog<T> extends BaseDialog<T> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  BaseFormDialog({
    super.key,
    required super.title,
    super.titleIcon,
    super.subtitle,
    super.primaryActionText,
    super.secondaryActionText,
    super.primaryActionIcon = Icons.save,
    super.primaryActionColor,
  });

  List<Widget> buildFormFields(BuildContext context);

  @override
  Widget buildContent(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: buildFormFields(context),
      ),
    );
  }

  @override
  bool validateBeforeAction() {
    return formKey.currentState?.validate() ?? false;
  }
}

/// Simple confirmation dialog extending BaseDialog with message display.
class ConfirmationDialog extends BaseDialog<bool> {
  final String message;
  final Widget? customContent;

  const ConfirmationDialog({
    super.key,
    required super.title,
    required this.message,
    this.customContent,
    super.titleIcon,
    super.primaryActionText = 'OK',
    super.secondaryActionText,
    super.isDangerous = false,
    super.primaryActionIcon,
  }) : super(primaryActionColor: null);

  @override
  Widget buildContent(BuildContext context) {
    return customContent ?? Text(message);
  }

  @override
  Future<bool?> performAction(BuildContext context) async {
    return true;
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    Widget? customContent,
    IconData? titleIcon,
    String primaryActionText = 'OK',
    String? secondaryActionText,
    bool isDangerous = false,
    IconData? primaryActionIcon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        customContent: customContent,
        titleIcon: titleIcon,
        primaryActionText: primaryActionText,
        secondaryActionText: secondaryActionText,
        isDangerous: isDangerous,
        primaryActionIcon: primaryActionIcon,
      ),
    );
  }
}

/// Destructive confirmation dialog for delete operations with warning styling.
class DestructiveConfirmationDialog extends BaseDialog<bool> {
  final String message;
  final String itemName;
  final Widget? customContent;

  const DestructiveConfirmationDialog({
    super.key,
    required super.title,
    required this.message,
    required this.itemName,
    this.customContent,
    super.primaryActionText,
    super.secondaryActionText,
  }) : super(
         titleIcon: Icons.warning_amber_rounded,
         isDangerous: true,
         primaryActionIcon: Icons.delete,
       );

  @override
  Widget buildContent(BuildContext context) {
    return customContent ??
        RichText(
          text: TextSpan(
            style: AppTextStyles.bodyMedium,
            children: [
              TextSpan(text: message),
              TextSpan(
                text: ' "$itemName"',
                style: AppTextStyles.bodyBold,
              ),
              const TextSpan(text: '?'),
            ],
          ),
        );
  }

  @override
  Future<bool?> performAction(BuildContext context) async {
    return true;
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String itemName,
    Widget? customContent,
    String? primaryActionText,
    String? secondaryActionText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DestructiveConfirmationDialog(
        title: title,
        message: message,
        itemName: itemName,
        customContent: customContent,
        primaryActionText: primaryActionText,
        secondaryActionText: secondaryActionText,
      ),
    );
  }
}

/// Base action dialog class with error handling and loading states for delete/edit operations.
abstract class BaseActionDialog<T> extends StatefulWidget {
  const BaseActionDialog({super.key});

  Widget buildContent(BuildContext context);
  Future<T> performAction(BuildContext context);
  bool validateBeforeAction() => true;

  Widget? get dialogIcon => null;
  String dialogTitleText(BuildContext context);
  String? get cancelButtonText => null;
  String actionButtonLabel(BuildContext context);
  String? loadingButtonLabel(BuildContext context) => null;
  Widget get actionButtonIcon => const Icon(Icons.check);
  ButtonStyle? actionButtonStyleFor(BuildContext context) => null;
  bool get isDestructiveAction => false;

  @override
  State<BaseActionDialog<T>> createState() =>
      BaseActionDialogState<BaseActionDialog<T>, T>();
}

class BaseActionDialogState<W extends BaseActionDialog<T>, T> extends State<W> {
  bool isLoading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: widget.dialogIcon,
      title: Text(widget.dialogTitleText(context)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.buildContent(context),
          if (error != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _buildErrorDisplay(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(widget.cancelButtonText ?? context.l10n.commonCancel),
        ),
        _buildActionButton(),
      ],
    );
  }

  Widget _buildActionButton() {
    final cs = Theme.of(context).colorScheme;
    final loadingText =
        widget.loadingButtonLabel(context) ?? context.l10n.commonWorking;
    final actionStyle = widget.actionButtonStyleFor(context);
    if (actionStyle != null) {
      return FilledButton.icon(
        onPressed: isLoading ? null : _performAction,
        style: actionStyle,
        icon: isLoading
            ? LoadingIndicator(
                size: 16,
                strokeWidth: 2,
                color: cs.surfaceContainerHighest,
              )
            : widget.actionButtonIcon,
        label: Text(
          isLoading ? loadingText : widget.actionButtonLabel(context),
        ),
      );
    } else {
      return FilledButton.icon(
        onPressed: isLoading ? null : _performAction,
        icon: isLoading
            ? const LoadingIndicator(size: 16, strokeWidth: 2)
            : widget.actionButtonIcon,
        label: Text(
          isLoading ? loadingText : widget.actionButtonLabel(context),
        ),
      );
    }
  }

  Future<void> _performAction() async {
    if (!widget.validateBeforeAction()) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await widget.performAction(context);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Dialog action failed: $e', stackTrace);
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildErrorDisplay() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        border: Border.all(color: cs.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading dialog with optional cancellation support.
class LoadingDialog extends StatelessWidget {
  final String message;
  final bool canCancel;

  const LoadingDialog({
    super.key,
    required this.message,
    this.canCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canCancel,
      child: AlertDialog(
        content: Row(
          children: [
            const LoadingIndicator(),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  static void show(
    BuildContext context, {
    required String message,
    bool canCancel = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: canCancel,
      builder: (context) => LoadingDialog(
        message: message,
        canCancel: canCancel,
      ),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}
