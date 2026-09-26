/// Collaborative shopping view with real-time shared list management.

// lib/views/social/collaborative_shopping_view.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

// Focused components (Phase 9 refactoring)
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_header.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_items.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_actions.dart';

/// Collaborative shopping view using facade pattern for real-time list coordination.
class CollaborativeShoppingView extends StatefulWidget {
  final String listId;

  const CollaborativeShoppingView({
    super.key,
    required this.listId,
  });

  @override
  State<CollaborativeShoppingView> createState() =>
      _CollaborativeShoppingViewState();
}

class _CollaborativeShoppingViewState extends State<CollaborativeShoppingView> {
  final TextEditingController _newItemController = TextEditingController();

  // State-owned VM (BUT-1226): created once per listId, provided via .value.
  // Handlers below read this field directly — the BUT-1212
  // ProviderNotFoundException class (context.read against the State's
  // above-provider context) is structurally impossible.
  late CollaborativeShoppingViewModel _vm;
  late CollaborativeShoppingActions _actions;

  @override
  void initState() {
    super.initState();
    _vm = _createViewModel();
    _vm.addListener(_onViewModelChanged);
    _actions = _createActions();
  }

  /// P6-U05: what the user had typed but not added when the role on this
  /// list dropped to read-only. Kept on screen until they close it, so the
  /// text is never lost to a timeout or cut off (produktregler.md:108).
  String? _unaddedText;

  /// P6-U05 (flows-roles-budget.md:83, :132): the role on this list dropped
  /// to read-only while it was open. The add field is gone at once (it is
  /// drawn only while the user can edit); a short snackbar says why, with
  /// "Stäng" (content-style-guide.md:97, :108). An item typed but not added
  /// is not written to the list; it stays in a notice in the view, with
  /// "Kopiera texten", until the user closes it ("osparat erbjuds som
  /// kopia", flows-roles-budget.md:83).
  void _onViewModelChanged() {
    if (!_vm.consumeEditAccessLost()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final typed = _newItemController.text.trim();
      if (typed.isNotEmpty) {
        setState(() => _unaddedText = typed);
        _newItemController.clear();
      }
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.roleLoweredShoppingList,
      );
    });
  }

  void _copyUnaddedText() {
    final typed = _unaddedText;
    if (typed == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: typed)));
    SnackBarUtils.showSuccess(context, context.l10n.roleLoweredTextCopied);
  }

  void _closeUnaddedText() => setState(() => _unaddedText = null);

  @override
  void didUpdateWidget(CollaborativeShoppingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The route normally recreates this view per list, but if an ancestor
    // rebinds listId in place (e.g. deep-link re-navigation reusing the
    // element) the VM must follow — it is constructed around a single listId.
    if (oldWidget.listId != widget.listId) {
      final oldVm = _vm;
      oldVm.removeListener(_onViewModelChanged);
      setState(() {
        _vm = _createViewModel();
        _vm.addListener(_onViewModelChanged);
        _actions = _createActions();
        _newItemController.clear();
        _unaddedText = null;
      });
      // Safe before the rebuild swaps providers: ChangeNotifier.removeListener
      // is explicitly allowed after dispose.
      oldVm.dispose();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    _newItemController.dispose();
    super.dispose();
  }

  CollaborativeShoppingViewModel _createViewModel() {
    return CollaborativeShoppingViewModel(
      listId: widget.listId,
      shoppingService: ServiceLocator.get(),
    );
  }

  CollaborativeShoppingActions _createActions() {
    return CollaborativeShoppingActions(
      viewModel: _vm,
      newItemController: _newItemController,
      onAddItem: _addItem,
      onMenuAction: _handleMenuAction,
      onShare: _shareList,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CollaborativeShoppingViewModel>.value(
      value: _vm,
      child: _CollaborativeShoppingViewContent(
        actions: _actions,
        onToggleItem: _toggleItem,
        unaddedText: _unaddedText,
        onCopyUnaddedText: _copyUnaddedText,
        onCloseUnaddedText: _closeUnaddedText,
      ),
    );
  }

  Future<void> _addItem() async {
    final itemName = _newItemController.text.trim();
    if (itemName.isEmpty) return;

    final success = await _vm.addItem(itemName);
    if (!mounted) return;

    if (success) {
      _newItemController.clear();
    } else {
      _showFailureReason();
    }
  }

  Future<void> _toggleItem(String itemId) async {
    final success = await _vm.toggleItemCompletion(itemId);
    if (!mounted) return;

    if (!success) {
      _showFailureReason();
      return;
    }

    // BUT-1201: announce the new bought/un-bought state to screen readers —
    // the visual checkbox change on the row isn't reliably read on toggle.
    final nowBought = _vm.completedItemsList.any((i) => i.id == itemId);
    SemanticsService.sendAnnouncement(
      View.of(context),
      nowBought ? context.l10n.a11yItemBought : context.l10n.a11yItemUnbought,
      TextDirection.ltr,
    );
  }

  /// BUT-1722: tell the shopper WHY the edit did not land.
  ///
  /// The item-operation reason comes first and is consumed: it is the specific
  /// one ("du har inte behörighet…", "listan finns inte längre", "ingen
  /// anslutning"), and on a shared list that distinction is the whole answer.
  /// Before this it had no reader, so a refused edit produced a row that
  /// flicked back and said nothing. The ViewModel's own [error] is the
  /// load-failure fallback.
  void _showFailureReason() {
    final reason = _vm.consumeItemOperationError() ?? _vm.error;
    if (reason == null || reason.isEmpty) return;
    SnackBarUtils.showError(context, reason);
  }

  void _shareList() {
    _actions.handleShare(context);
  }

  void _handleMenuAction(String action) {
    _actions.handleMenuAction(context, action);
  }
}

/// Actual UI — rebuilds via `context.watch` on the State-owned VM above.
class _CollaborativeShoppingViewContent extends StatelessWidget {
  final CollaborativeShoppingActions actions;
  final ValueChanged<String> onToggleItem;
  final String? unaddedText;
  final VoidCallback onCopyUnaddedText;
  final VoidCallback onCloseUnaddedText;

  const _CollaborativeShoppingViewContent({
    required this.actions,
    required this.onToggleItem,
    required this.unaddedText,
    required this.onCopyUnaddedText,
    required this.onCloseUnaddedText,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CollaborativeShoppingViewModel>();

    return Scaffold(
      appBar: actions.buildAppBar(context),
      body: SafeArea(
        // Responsive: center and constrain content on large screens.
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 800,
                desktop: 900,
              ),
            ),
            child: Column(
              children: [
                LayoutComponents.offlineIndicator(),
                // BUT-1162: surface silent collaborative-edit conflict
                // resolutions on this shared list (drop-in; idle-collapses).
                ConflictBanner(filterDocId: viewModel.listId),
                Expanded(child: _buildBody(context, viewModel)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CollaborativeShoppingViewModel viewModel,
  ) {
    return LoadingStateBuilder<dynamic>(
      isLoading: viewModel.isLoading,
      error: viewModel.error,
      data: viewModel.currentList,
      loadingMessage: context.l10n.collaborativeLoadingSharedList,
      emptyBuilder: (context) => _buildNotFoundState(context),
      builder: (context, shoppingList) => _buildListContent(context, viewModel),
      onErrorRetry: () {
        viewModel.clearError();
        viewModel.refresh();
      },
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: AppDimensions.iconSizeXl,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              context.l10n.collaborativeListNotFound,
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              context.l10n.collaborativeListNoAccess,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text(context.l10n.commonBack),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent(
    BuildContext context,
    CollaborativeShoppingViewModel viewModel,
  ) {
    return Column(
      children: [
        CollaborativeShoppingHeader(viewModel: viewModel),
        actions.buildAddItemSection(context),
        if (unaddedText != null)
          _UnaddedTextNotice(
            text: unaddedText!,
            onCopy: onCopyUnaddedText,
            onClose: onCloseUnaddedText,
          ),
        Expanded(
          child: CollaborativeShoppingItems(
            viewModel: viewModel,
            onToggleItem: onToggleItem,
          ),
        ),
      ],
    );
  }
}

/// P6-U05: the item a user had typed but not added when their role on the
/// list dropped to read-only, kept in the view until they close it.
///
/// No drawing shows it. It uses the neutral notice anatomy of the recipe
/// suggestion line (the conflict banner of Komponentark v1:755-757 without
/// the danger colour): surface.base with a 1 px border.subtle outline and the
/// 8 px control radius, text.body. colorScheme.surface is surface.base
/// (#F5F4ED / #17251D, tokens.json:104-106), outlineVariant is border.subtle
/// (#CCD1C2 / rgba(245,244,237,0.18), tokens.json:124-127) and
/// AppModeColors.textBody is text.body (#37453A / #F5F4ED, tokens.json:58-60).
/// The typed text is body text, so it is never cut off
/// (content-style-guide.md:109) and can be selected as well as copied.
class _UnaddedTextNotice extends StatelessWidget {
  const _UnaddedTextNotice({
    required this.text,
    required this.onCopy,
    required this.onClose,
  });

  final String text;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    final body = AppModeColors.textBody(theme.brightness);
    return Padding(
      key: const ValueKey('collaborativeShopping.unaddedText'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          side: BorderSide(
            color: cs.outlineVariant,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingModerate,
            AppDimensions.paddingS,
            AppDimensions.spacingXs,
            AppDimensions.spacingXs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.roleLoweredShoppingUnsaved,
                style: AppTextStyles.captionBase.copyWith(color: body),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              SelectableText(
                text,
                style: AppTextStyles.bodyMedium.copyWith(color: body),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  children: [
                    TextButton(
                      onPressed: onCopy,
                      child: Text(l.roleLoweredCopyText),
                    ),
                    TextButton(
                      onPressed: onClose,
                      child: Text(l.commonClose),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
