// lib/widgets/common/dialogs/menu_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Simple dialog for selecting a menu to share with a group
class MenuSelectionDialog extends StatefulWidget {
  final String groupName;

  const MenuSelectionDialog({
    super.key,
    required this.groupName,
  });

  @override
  State<MenuSelectionDialog> createState() => _MenuSelectionDialogState();
}

class _MenuSelectionDialogState extends State<MenuSelectionDialog> {
  late final UnifiedMenuService _menuService;
  bool _isLoading = true;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _menuService = ServiceLocator.get<UnifiedMenuService>();
    _initializeMenuService();
  }

  Future<void> _initializeMenuService() async {
    if (!mounted) return;

    try {
      final permissionService = ServiceLocator.get<PermissionService>();
      final currentUserId = permissionService.currentUserId;

      AppLogger.debug('🔍 [MenuDialog] Starting initialization');
      AppLogger.debug('   Service initialized: ${_menuService.isInitialized}');
      AppLogger.debug('   Current user: $currentUserId');
      AppLogger.debug(
        '   Is authenticated: ${permissionService.isAuthenticated}',
      );

      // Initialize menu service if not already initialized, otherwise refresh
      if (!_menuService.isInitialized) {
        AppLogger.debug('   Initializing menu service...');
        await _menuService.initialize();
        AppLogger.debug('   ✅ Service initialized');
      } else {
        AppLogger.debug('   Service already initialized, refreshing menus...');
        await _menuService.refresh();
        AppLogger.debug('   ✅ Menus refreshed');
      }

      final menuCount = _menuService.menus.length;
      AppLogger.debug('   📋 Loaded $menuCount menus from service');

      if (menuCount == 0) {
        AppLogger.warning(
          '⚠️ [MenuDialog] Menu service initialized but returned 0 menus',
        );
        AppLogger.debug('   This could mean:');
        AppLogger.debug('   1. User has no menus created yet');
        AppLogger.debug('   2. Firestore query returned empty');
        AppLogger.debug('   3. Parse errors occurred (check logs above)');
      } else {
        AppLogger.success(
          '✅ [MenuDialog] Successfully loaded $menuCount menus',
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MenuDialog] Menu initialization failed', e);
      AppLogger.error('   Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '${context.l10n.errorCouldNotLoad('menyer')}: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.l10n.dialogShareMenuWith(widget.groupName),
        style: AppTextStyles.headlineSmall,
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            context.l10n.commonCancel,
            style: AppTextStyles.labelLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    // Loading state
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              context.l10n.dialogLoadingMenus,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Error state
    if (_error != null) {
      return StateWidget.error(
        message: _error!,
        actionLabel: context.l10n.commonRetry,
        onAction: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _initializeMenuService();
        },
      );
    }

    // Get menus after successful initialization
    final menus = _isInitialized ? _menuService.menus : <SharedMenu>[];

    // Empty state
    if (menus.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.dialogNoMenus,
        subtitle: context.l10n.dialogNoMenusToShare,
        icon: Icons.calendar_today,
      );
    }

    // Menu list
    return ListView.builder(
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        return _MenuListItem(
          menu: menu,
          onTap: () => Navigator.pop(context, menu),
        );
      },
    );
  }
}

/// Menu list item widget
class _MenuListItem extends StatelessWidget {
  final SharedMenu menu;
  final VoidCallback onTap;

  const _MenuListItem({
    required this.menu,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      leading: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            width: AppDimensions.iconSizeXl,
            height: AppDimensions.iconSizeXl,
            decoration: BoxDecoration(
              color: cs.primary.withValues(
                alpha: AppDimensions.opacityVeryLight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: Icon(
              Icons.calendar_today,
              color: cs.primary,
              size: AppDimensions.iconSizeAction,
            ),
          );
        },
      ),
      title: Text(
        menu.menuTitle,
        style: AppTextStyles.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (menu.shareMessage != null && menu.shareMessage!.isNotEmpty)
            Text(
              menu.shareMessage!,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            context.l10n.recipeCountBadge(menu.totalRecipeCount),
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: AppDimensions.iconSizeS,
      ),
      onTap: onTap,
    );
  }
}
