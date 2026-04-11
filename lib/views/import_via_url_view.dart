// lib/views/import_via_url_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Import via URL view with sourceUrl support
class ImportViaUrlView extends StatefulWidget {
  const ImportViaUrlView({super.key});

  @override
  State<ImportViaUrlView> createState() => _ImportViaUrlViewState();
}

class _ImportViaUrlViewState extends State<ImportViaUrlView> {
  late final UrlImportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<UrlImportViewModel>();
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
      child: const _ImportViaUrlViewContent(),
    );
  }
}

class _ImportViaUrlViewContent extends StatefulWidget {
  const _ImportViaUrlViewContent();

  @override
  State<_ImportViaUrlViewContent> createState() =>
      _ImportViaUrlViewContentState();
}

class _ImportViaUrlViewContentState extends State<_ImportViaUrlViewContent> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _extractedTextController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _extractedTextController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final viewModel = context.read<UrlImportViewModel>();
    viewModel.updateUrl(_urlController.text);
  }

  void _fetchPage() {
    final viewModel = context.read<UrlImportViewModel>();
    viewModel.fetchFromUrl();
  }

  void _navigateToTextImport() {
    final viewModel = context.read<UrlImportViewModel>();
    if (viewModel.hasExtractedText) {
      // Use edited text from controller instead of original extracted text
      final editedText = _extractedTextController.text.trim();
      if (editedText.isNotEmpty) {
        Navigator.pushNamed(
          context,
          '/franSocialaMedier',
          arguments: {
            'text': editedText,
            'sourceUrl': viewModel.sourceUrl,
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UrlImportViewModel>();

    return LayoutComponents.mainMenu(
      currentIndex: null,
      title: context.l10n.importViaUrl,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
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
              child: Padding(
                padding: AppDimensions.responsiveContentPadding(context),
                child: Column(
                  children: [
                    // URL input
                    StyledInput(
                      controller: _urlController,
                      enabled: !viewModel.isLoading,
                      label: context.l10n.importPasteRecipeUrl,
                      hint: 'https://example.com/recept',
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      // Note: onFieldSubmitted functionality moved to fetch button
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Fetch button
                    ActionButtons.primaryButton(
                      context,
                      label: context.l10n.importFetchText,
                      onPressed: viewModel.canFetch && !viewModel.isLoading
                          ? _fetchPage
                          : null,
                      isLoading: viewModel.isLoading,
                      loadingText: context.l10n.importFetching,
                      isExpanded: true,
                    ),

                    // Error visning
                    if (viewModel.hasError) ...[
                      const SizedBox(height: AppDimensions.spacingXl),
                      StateWidget.error(
                        message: viewModel.error!,
                      ),
                    ],

                    // Extraherad text (editable)
                    if (viewModel.hasExtractedText) ...[
                      const SizedBox(height: AppDimensions.spacingXl),
                      Text(context.l10n.importExtractedText,
                          style: AppTextStyles.headlineSmall),
                      const SizedBox(height: AppDimensions.spacingS),
                      Expanded(
                        child: StyledInput(
                          controller: _extractedTextController
                            ..text = viewModel.extractedText,
                          maxLines: null,
                          minLines: 10,
                          label: context.l10n.importEditTextBeforeImport,
                          hint: context.l10n.importEditTextHint,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      ActionButtons.primaryButton(
                        context,
                        label: context.l10n.importProceedToPaste,
                        onPressed: _navigateToTextImport,
                        isExpanded: true,
                      ),
                    ],
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
