/// Text import view for parsing recipes from social media and copied text.

// lib/views/fran_sociala_medier_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/source_url_display.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Text import view for parsing recipes from copied text.
class FranSocialaMedierView extends StatefulWidget {
  final String? initialText;
  final String? sourceUrl;

  const FranSocialaMedierView({
    super.key,
    this.initialText,
    this.sourceUrl,
  });

  @override
  State<FranSocialaMedierView> createState() => _FranSocialaMedierViewState();
}

class _FranSocialaMedierViewState extends State<FranSocialaMedierView> {
  late final TextImportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<TextImportViewModel>();
    if (widget.sourceUrl != null) {
      _viewModel.setSourceUrl(widget.sourceUrl!);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: _FranSocialaMedierViewContent(
        initialText: widget.initialText,
        sourceUrl: widget.sourceUrl,
      ),
    );
  }
}

class _FranSocialaMedierViewContent extends StatefulWidget {
  final String? initialText;
  final String? sourceUrl;

  const _FranSocialaMedierViewContent({
    this.initialText,
    this.sourceUrl,
  });

  @override
  State<_FranSocialaMedierViewContent> createState() =>
      _FranSocialaMedierViewContentState();
}

class _FranSocialaMedierViewContentState
    extends State<_FranSocialaMedierViewContent> {
  late TextEditingController _textController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    _textController = TextEditingController(text: widget.initialText ?? '');

    // Update ViewModel with initial text after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialText != null && widget.initialText!.isNotEmpty) {
        final viewModel = context.read<TextImportViewModel>();
        viewModel.updateInputText(widget.initialText!);
        viewModel.parseText();
      }
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parseAndNavigate(BuildContext context) async {
    final viewModel = context.read<TextImportViewModel>();
    final success = await viewModel.parseText();

    if (success && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SkrivSjalvReceptView(
            initialRecipe: viewModel.parsedRecipe,
            isTemplate: true,
          ),
        ),
      );
    } else if (context.mounted && viewModel.hasError) {
      // Use UtilityComponents.showErrorSnackbar
      UtilityComponents.showErrorSnackbar(context, viewModel.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TextImportViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importFromSocialMedia)),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: SingleChildScrollView(
              padding: AppDimensions.responsiveContentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instruktionstext
                  _buildInstructions(context),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // Show if recipe comes from URL
                  if (viewModel.sourceUrl != null) ...[
                    SourceUrlDisplay(sourceUrl: viewModel.sourceUrl!),
                    const SizedBox(height: AppDimensions.spacingM),
                  ],

                  // Text field for recipe
                  _buildTextInput(context, viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
                  UtilityComponents.primaryButton(
                    context,
                    label: context.l10n.importPreviewAndEdit,
                    icon: Icons.preview,
                    onPressed: viewModel.isParsing || !viewModel.canParse
                        ? null
                        : () => _parseAndNavigate(context),
                    isLoading: viewModel.isParsing,
                    loadingText: context.l10n.importParsingText,
                    isExpanded: true,
                  ),

                  // Error message
                  if (viewModel.hasError) ...[
                    const SizedBox(height: AppDimensions.spacingM),
                    StateWidget.error(
                      message: viewModel.error!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                context.l10n.importTipsTitle,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            context.l10n.importTipsContent,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(BuildContext context, TextImportViewModel viewModel) {
    // Synchronize ViewModel text with controller if they differ
    if (_isInitialized && _textController.text != viewModel.inputText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_textController.text != viewModel.inputText) {
          _textController.text = viewModel.inputText;
        }
      });
    }

    return Container(
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 400,
      ),
      child: TextField(
        controller: _textController,
        onChanged: viewModel.updateInputText,
        decoration: InputDecoration(
          hintText: context.l10n.importPasteRecipeHint,
          hintMaxLines: 10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        keyboardType: TextInputType.multiline,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.bodyMedium,
      ),
    );
  }
}
