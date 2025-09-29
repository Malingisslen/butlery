// lib/views/unified_shopping/widgets/shopping_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Dialog-related functionality for shopping view
class ShoppingDialogs {
  static Future<void> showAddItemDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final result = await showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => _AddItemDialog(viewModel: viewModel),
    );

    if (result != null) {
      try {
        final success = await viewModel.addItemToActiveList(
          name: result.name,
          amount: result.amount,
          unit: result.unit,
          category: result.category,
          note: result.note,
          estimatedPrice: result.estimatedPrice,
          priority: result.priority,
        );

        if (success) {
          onSuccess('${result.name} tillagd!');
        } else {
          onError('Kunde inte lägga till ${result.name}');
        }
      } catch (e) {
        onError('Fel vid tillägg: $e');
      }
    }
  }

  static Future<void> showEditItemDialog(
    BuildContext context,
    UnifiedShoppingItem item,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final result = await showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => _EditItemDialog(item: item, viewModel: viewModel),
    );

    if (result != null) {
      try {
        final success = await viewModel.updateItem(
          itemId: item.id,
          name: result.name,
          quantity: result.amount,
          unit: result.unit,
          category: result.category,
          notes: result.note,
          estimatedPrice: result.estimatedPrice,
          priority: result.priority,
        );

        if (success) {
          onSuccess('${result.name} uppdaterad!');
        } else {
          onError('Kunde inte uppdatera ${result.name}');
        }
      } catch (e) {
        onError('Fel vid uppdatering: $e');
      }
    }
  }

  static Future<void> showShareDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) async {
    if (viewModel.activeList == null) return;

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      AppLogger.info('Initializing friends service for sharing...');
      await friendsService.initialize();
      final availableFriends = friendsService.friends;
      AppLogger.info('Loaded ${availableFriends.length} friends for sharing');

      if (availableFriends.isEmpty) {
        AppLogger.warning('No friends available - showing info dialog');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Inga vänner'),
              content: const Text('Du har inga vänner att dela med än. Lägg till vänner först.'),
              actions: [
                ActionButtons.primaryButton(
                  context,
                  label: 'OK',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
        return;
      }

      final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
      if (context.mounted) {
        AppLogger.info('Showing share dialog for list: ${viewModel.activeList!.name}');
        await showDialog(
          context: context,
          builder: (context) => UniversalShareDialog.shoppingList(
            shoppingList: viewModel.activeList!,
            viewModel: shareViewModel,
            availableFriends: availableFriends,
          ),
        );
        AppLogger.info('Share dialog completed');
      }
    } catch (e) {
      AppLogger.error('Error showing share dialog: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte visa delningsdialog: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  static Future<void> showSharingStatus(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) async {
    final activeList = viewModel.activeList;
    if (activeList == null) return;

    // Pre-load user profiles for collaborative lists
    final Map<String, String> userDisplayNames = {};
    if (activeList.isCollaborative) {
      try {
        final userService = ServiceLocator.get<UserService>();
        final allUserIds = <String>{
          activeList.ownerId,
          ...activeList.memberPermissions.keys,
        }.toList();
        
        final profiles = await userService.getUserProfiles(allUserIds);
        for (final profile in profiles) {
          userDisplayNames[profile.uid] = profile.displayName;
        }
        
        // Fallback for owner display name if not loaded
        if (!userDisplayNames.containsKey(activeList.ownerId) && activeList.ownerDisplayName.isNotEmpty) {
          userDisplayNames[activeList.ownerId] = activeList.ownerDisplayName;
        }
      } catch (e) {
        AppLogger.warning('Could not load user profiles for sharing dialog: $e');
        // Fallback to owner display name if not empty
        if (activeList.ownerDisplayName.isNotEmpty) {
          userDisplayNames[activeList.ownerId] = activeList.ownerDisplayName;
        }
      }
    }

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => _SharingStatusDialog(
          list: activeList,
          userDisplayNames: userDisplayNames,
        ),
      );
    }
  }


  static Future<void> showCreateListDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    final name = await DialogFactory.showTextInput(
      context,
      title: 'Skapa ny lista',
      hintText: 'T.ex. Veckohandling',
      confirmText: 'Skapa',
      required: true,
    );

    if (name != null && name.isNotEmpty) {
      await viewModel.createPersonalList(name);
      onSuccess('Lista "$name" skapad!');
    }
  }

  static Future<void> showClearCompletedConfirmation(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    if (viewModel.boughtItems == 0) return;

    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: 'Töm inhandlade varor',
      message: 'Vill du ta bort alla ${viewModel.boughtItems} inhandlade varor från listan?',
      confirmText: 'Töm',
      isDangerous: true,
    );

    if (confirmed == true) {
      await viewModel.clearBoughtItems();
      onSuccess('Inhandlade varor rensade!');
    }
  }

  /// Show rename list dialog with text input validation
  static Future<void> showRenameListDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final textController = TextEditingController(text: list.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Byt namn på lista'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nuvarande namn: "${list.name}"',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              StyledInput(
                controller: textController,
                autofocus: true,
                label: 'Nytt namn',
                hint: 'Ange det nya namnet för listan',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Namn får inte vara tomt';
                  }
                  if (value.trim().length < 2) {
                    return 'Namnet måste vara minst 2 tecken';
                  }
                  if (value.trim().length > 50) {
                    return 'Namnet får inte vara längre än 50 tecken';
                  }
                  return null;
                },
                maxLength: 50,
              ),
            ],
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Spara',
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newName = textController.text.trim();
                Navigator.pop(context, newName);
              }
            },
          ),
        ],
      ),
    );

    if (result != null && result != list.name) {
      final success = await viewModel.renameList(list.id, result);
      if (success) {
        onSuccess('Lista döpt om till "$result"');
      } else {
        onError('Kunde inte döpa om listan');
      }
    }
  }

  /// Show delete list confirmation dialog with item count warning
  static Future<void> showDeleteListConfirmationDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: 'Ta bort lista',
      message: list.items.isEmpty
          ? 'Är du säker på att du vill ta bort listan "${list.name}"?'
          : 'Är du säker på att du vill ta bort listan "${list.name}"?\n\nListan innehåller ${list.items.length} artiklar som kommer att försvinna permanent.',
      confirmText: 'Ta bort',
      cancelText: 'Avbryt',
      isDangerous: true,
    );

    if (confirmed == true) {
      final success = await viewModel.deleteList(list.id);
      if (success) {
        onSuccess('Lista "${list.name}" borttagen');
      } else {
        onError('Kunde inte ta bort listan');
      }
    }
  }
}

class _AddItemDialog extends StatefulWidget {
  final UnifiedShoppingViewModel viewModel;

  const _AddItemDialog({required this.viewModel});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _unitController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lägg till vara'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: _nameController,
              label: 'Varunamn',
              hint: 'T.ex. Mjölk',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Varunamn krävs';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: StyledInput(
                    controller: _amountController,
                    label: 'Mängd',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: StyledInput(
                    controller: _unitController,
                    label: 'Enhet',
                    hint: 'st, liter, kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _categoryController,
              label: 'Kategori',
              hint: 'T.ex. Mejeri',
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _noteController,
              label: 'Anteckning (valfritt)',
              hint: 'T.ex. Laktosfri',
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: 'Avbryt',
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: 'Lägg till',
          onPressed: _onSave,
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final item = UnifiedShoppingItem.basic(
        name: _nameController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? 1.0,
        unit: _unitController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Övrigt'
            : _categoryController.text.trim(),
      );

      Navigator.pop(context, item);
    }
  }
}

class _EditItemDialog extends StatefulWidget {
  final UnifiedShoppingItem item;
  final UnifiedShoppingViewModel viewModel;

  const _EditItemDialog({required this.item, required this.viewModel});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController = TextEditingController(text: widget.item.amount.toString());
    _unitController = TextEditingController(text: widget.item.unit);
    _categoryController = TextEditingController(text: widget.item.category);
    _noteController = TextEditingController(text: widget.item.note ?? '');
    _priceController = TextEditingController(text: widget.item.estimatedPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redigera vara'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyledInput(
              controller: _nameController,
              label: 'Varunamn',
              hint: 'T.ex. Mjölk',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Varunamn krävs';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: StyledInput(
                    controller: _amountController,
                    label: 'Mängd',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 3,
                  child: StyledInput(
                    controller: _unitController,
                    label: 'Enhet',
                    hint: 'st, liter, kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _categoryController,
              label: 'Kategori',
              hint: 'T.ex. Mejeri',
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _noteController,
              label: 'Anteckning (valfritt)',
              hint: 'T.ex. Laktosfri',
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: 'Avbryt',
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: 'Spara',
          onPressed: _onSave,
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final item = widget.item.copyWith(
        name: _nameController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? widget.item.amount,
        unit: _unitController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Övrigt'
            : _categoryController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        estimatedPrice: _priceController.text.trim().isEmpty
            ? null
            : double.tryParse(_priceController.text),
        priority: widget.item.priority,
      );

      Navigator.pop(context, item);
    }
  }
}

/// Comprehensive sharing status dialog showing detailed information about list collaboration
class _SharingStatusDialog extends StatelessWidget {
  final UnifiedShoppingList list;
  final Map<String, String> userDisplayNames;

  const _SharingStatusDialog({
    required this.list,
    this.userDisplayNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final permissionService = ServiceLocator.get<PermissionService>();
    final userService = ServiceLocator.get<UserService>();
    final currentUserId = permissionService.currentUser?.uid;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getListTypeIcon(),
            color: _getListTypeColor(),
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              _getDialogTitle(),
              style: AppTextStyles.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // List Information Section
              _buildListInfoSection(context),
              
              // Your Permission Section
              if (currentUserId != null && list.isCollaborative) ...[
                const SizedBox(height: AppDimensions.spacingL),
                _buildPermissionSection(context, currentUserId),
              ],
              
              // Members Section (for collaborative lists)
              if (list.isCollaborative) ...[
                const SizedBox(height: AppDimensions.spacingL),
                _buildMembersSection(context, userService),
              ],
              
              // Activity Section
              if (list.lastActivityAt != null) ...[
                const SizedBox(height: AppDimensions.spacingL),
                _buildActivitySection(context),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (list.isCollaborative && currentUserId != null && _canManageSharing(currentUserId))
          ActionButtons.secondaryButton(
            context,
            label: 'Hantera delning',
            icon: Icons.manage_accounts,
            onPressed: () {
              Navigator.pop(context);
              _showManageSharing(context);
            },
          ),
        ActionButtons.primaryButton(
          context,
          label: 'Stäng',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildListInfoSection(BuildContext context) {
    return Card(
      color: _getListTypeColor().withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listinformation',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            _buildInfoRow('Namn', list.name),
            _buildInfoRow('Typ', _getListTypeLabel()),
            _buildInfoRow('Skapare', list.ownerDisplayName),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection(BuildContext context, String currentUserId) {
    final userPermission = list.memberPermissions[currentUserId];
    final isOwner = list.ownerId == currentUserId;
    
    String permissionLabel;
    String permissionDescription;
    IconData permissionIcon;
    Color permissionColor;
    
    if (isOwner) {
      permissionLabel = 'Administratör (Ägare)';
      permissionDescription = 'Du äger denna lista och kan hantera alla aspekter av den';
      permissionIcon = Icons.admin_panel_settings;
      permissionColor = AppColors.primaryBlue;
    } else {
      switch (userPermission) {
        case SharedListPermission.view:
          permissionLabel = 'Kan bara se';
          permissionDescription = 'Du kan se listan och alla artiklar men inte redigera';
          permissionIcon = Icons.visibility;
          permissionColor = AppColors.textMedium;
          break;
        case SharedListPermission.edit:
          permissionLabel = 'Kan redigera';
          permissionDescription = 'Du kan lägga till, ta bort och ändra artiklar i listan';
          permissionIcon = Icons.edit;
          permissionColor = AppColors.accent;
          break;
        case SharedListPermission.admin:
          permissionLabel = 'Administratör';
          permissionDescription = 'Du kan redigera listan och hantera medlemmarnas behörigheter';
          permissionIcon = Icons.admin_panel_settings;
          permissionColor = AppColors.primaryBlue;
          break;
        default:
          permissionLabel = 'Ej specificerad';
          permissionDescription = 'Din behörighetsnivå är inte tydligt definierad';
          permissionIcon = Icons.help;
          permissionColor = AppColors.textMedium;
      }
    }

    return Card(
      color: permissionColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(permissionIcon, color: permissionColor, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  'Din behörighet',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              permissionLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              permissionDescription,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(BuildContext context, UserService userService) {
    final allMembers = <String, SharedListPermission>{};
    
    // Add owner if not already in permissions
    if (!list.memberPermissions.containsKey(list.ownerId)) {
      allMembers[list.ownerId] = SharedListPermission.admin;
    }
    
    // Add all members with permissions
    allMembers.addAll(list.memberPermissions);

    return Card(
      color: AppColors.primaryBlue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: AppColors.primaryBlue, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  'Medlemmar (${allMembers.length})',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            ...allMembers.entries.map((entry) {
              final isOwner = entry.key == list.ownerId;
              return _buildMemberRow(entry.key, entry.value, isOwner);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(String userId, SharedListPermission permission, bool isOwner) {
    final String displayName = userDisplayNames[userId] ?? 'Okänd användare';
    
    String permissionLabel;
    IconData permissionIcon;
    Color permissionColor;
    
    if (isOwner) {
      permissionLabel = 'Ägare';
      permissionIcon = Icons.admin_panel_settings;
      permissionColor = AppColors.primaryBlue;
    } else {
      switch (permission) {
        case SharedListPermission.view:
          permissionLabel = 'Kan se';
          permissionIcon = Icons.visibility;
          permissionColor = AppColors.textMedium;
          break;
        case SharedListPermission.edit:
          permissionLabel = 'Kan redigera';
          permissionIcon = Icons.edit;
          permissionColor = AppColors.accent;
          break;
        case SharedListPermission.admin:
          permissionLabel = 'Admin';
          permissionIcon = Icons.admin_panel_settings;
          permissionColor = AppColors.primaryBlue;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(permissionIcon, size: AppDimensions.iconSizeS, color: permissionColor),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      permissionLabel,
                      style: AppTextStyles.bodySmall.copyWith(color: permissionColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    return Card(
      color: AppColors.primaryBlue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.primaryBlue, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  'Senaste aktivitet',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            if (list.lastActivityByDisplayName != null)
              _buildInfoRow('Av', list.lastActivityByDisplayName!),
            if (list.lastActivityAt != null)
              _buildInfoRow('När', _formatDateTime(list.lastActivityAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getListTypeIcon() {
    switch (list.type) {
      case ListType.personal:
        return Icons.person;
      case ListType.collaborative:
        return Icons.people;
      case ListType.template:
        return Icons.bookmark;
    }
  }

  Color _getListTypeColor() {
    switch (list.type) {
      case ListType.personal:
        return AppColors.primaryBlue;
      case ListType.collaborative:
        return AppColors.primaryBlue;
      case ListType.template:
        return AppColors.textMedium;
    }
  }

  String _getListTypeLabel() {
    switch (list.type) {
      case ListType.personal:
        return 'Personlig lista';
      case ListType.collaborative:
        return 'Delad lista';
      case ListType.template:
        return 'Mall-lista';
    }
  }

  String _getDialogTitle() {
    return 'Lista: ${list.name}';
  }

  bool _canManageSharing(String currentUserId) {
    if (list.ownerId == currentUserId) return true;
    final userPermission = list.memberPermissions[currentUserId];
    return userPermission == SharedListPermission.admin;
  }

  Future<void> _showManageSharing(BuildContext context) async {
    try {
      // Load available friends for adding new members
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      await friendsService.initialize();
      final availableFriends = friendsService.friends;
      
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => _MemberManagementDialog(
            list: list,
            userDisplayNames: userDisplayNames,
            availableFriends: availableFriends,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error loading friends for member management: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte ladda vänner: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Nyss';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.year}';
    }
  }
}

/// Comprehensive member management dialog for collaborative shopping list administration
class _MemberManagementDialog extends StatefulWidget {
  final UnifiedShoppingList list;
  final Map<String, String> userDisplayNames;
  final List<UserProfile> availableFriends;

  const _MemberManagementDialog({
    required this.list,
    required this.userDisplayNames,
    required this.availableFriends,
  });

  @override
  State<_MemberManagementDialog> createState() => _MemberManagementDialogState();
}

class _MemberManagementDialogState extends State<_MemberManagementDialog> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<UserProfile> _filteredFriends = [];
  final Set<String> _selectedFriends = {};
  
  // Local state for member permissions to reflect real-time changes
  late Map<String, SharedListPermission> _localPermissions;
  late Set<String> _localMemberIds;

  @override
  void initState() {
    super.initState();
    
    // Initialize local state from widget data
    _localPermissions = Map<String, SharedListPermission>.from(widget.list.memberPermissions);
    
    // Add owner if not already in permissions
    if (!_localPermissions.containsKey(widget.list.ownerId)) {
      _localPermissions[widget.list.ownerId] = SharedListPermission.admin;
    }
    
    _localMemberIds = Set<String>.from(_localPermissions.keys);
    _updateFilteredFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredFriends() {
    final query = _searchController.text.toLowerCase();
    
    _filteredFriends = widget.availableFriends
        .where((friend) => !_localMemberIds.contains(friend.uid))
        .where((friend) => friend.displayName.toLowerCase().contains(query))
        .toList();
    
    setState(() {});
  }

  Future<void> _updateMemberPermission(String userId, SharedListPermission newPermission) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final success = await shoppingService.collaborative.updateMemberPermission(
        listId: widget.list.id,
        userId: userId,
        permission: newPermission,
      );

      if (success) {
        // Update local state to reflect the change immediately
        setState(() {
          _localPermissions[userId] = newPermission;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Behörighet uppdaterad för ${widget.userDisplayNames[userId] ?? 'användare'}'),
              backgroundColor: AppColors.primaryBlue,
              duration: const Duration(seconds: 2),
            ),
          );
          // Don't close dialog - let user see the change and continue managing
        }
      } else {
        setState(() {
          _error = 'Kunde inte uppdatera behörighet';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fel vid uppdatering: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort medlem'),
        content: Text('Är du säker på att du vill ta bort $userName från listan?'),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Ta bort',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final success = await shoppingService.collaborative.removeMember(
        listId: widget.list.id,
        userId: userId,
      );

      if (success) {
        // Update local state to reflect the removal immediately
        setState(() {
          _localPermissions.remove(userId);
          _localMemberIds.remove(userId);
          _updateFilteredFriends(); // Refresh available friends list
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName borttagen från listan'),
              backgroundColor: AppColors.primaryBlue,
              duration: const Duration(seconds: 2),
            ),
          );
          // Don't close dialog - let user continue managing other members
        }
      } else {
        setState(() {
          _error = 'Kunde inte ta bort medlem';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fel vid borttagning: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedFriends.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final addedMembers = <String>[];
      
      for (final friendId in _selectedFriends) {
        final friend = widget.availableFriends.firstWhere((f) => f.uid == friendId);
        final success = await shoppingService.collaborative.addMember(
          listId: widget.list.id,
          userId: friendId,
          userDisplayName: friend.displayName,
          permission: SharedListPermission.edit,
        );
        
        if (success) {
          addedMembers.add(friendId);
        }
      }
      
      // Update local state for successfully added members
      if (addedMembers.isNotEmpty) {
        setState(() {
          for (final friendId in addedMembers) {
            _localPermissions[friendId] = SharedListPermission.edit;
            _localMemberIds.add(friendId);
          }
          _selectedFriends.clear();
          _updateFilteredFriends();
        });
      }

      if (mounted) {
        if (addedMembers.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${addedMembers.length} ${addedMembers.length == 1 ? 'medlem' : 'medlemmar'} tillagda'),
              backgroundColor: AppColors.primaryBlue,
              duration: const Duration(seconds: 2),
            ),
          );
          // Don't close dialog - let user continue managing members
        } else {
          setState(() {
            _error = 'Kunde inte lägga till några medlemmar';
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Fel vid tillägg: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use local permissions state instead of static widget data
    final allMembers = Map<String, SharedListPermission>.from(_localPermissions);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.manage_accounts, size: AppDimensions.iconSizeAction),
          SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              'Hantera delning',
              style: AppTextStyles.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500, // Fixed height for better UX
        child: Column(
          children: [
            // Error display
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                child: Text(
                  _error!,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
            ],

            // Members section
            Text(
              'Nuvarande medlemmar (${allMembers.length})',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                child: ListView.builder(
                  itemCount: allMembers.length,
                  itemBuilder: (context, index) {
                    final entry = allMembers.entries.elementAt(index);
                    final userId = entry.key;
                    final permission = entry.value;
                    final isOwner = userId == widget.list.ownerId;
                    final userName = widget.userDisplayNames[userId] ?? 'Okänd användare';
                    
                    return _buildMemberListTile(userId, userName, permission, isOwner);
                  },
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.spacingL),
            const Divider(),
            const SizedBox(height: AppDimensions.spacingM),

            // Add members section
            Text(
              'Lägg till vänner',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Search field
            StyledInput(
              controller: _searchController,
              hint: 'Sök vänner...',
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => _updateFilteredFriends(),
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Friends list
            Expanded(
              flex: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                child: _filteredFriends.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isNotEmpty 
                              ? 'Inga vänner hittades'
                              : 'Alla vänner är redan medlemmar',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _filteredFriends[index];
                          return _buildFriendListTile(friend);
                        },
                      ),
              ),
            ),

            // Add selected friends button
            if (_selectedFriends.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingM),
              SizedBox(
                width: double.infinity,
                child: ActionButtons.primaryButton(
                  context,
                  label: 'Lägg till ${_selectedFriends.length} vän${_selectedFriends.length == 1 ? '' : 'ner'}',
                  icon: Icons.person_add,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _addSelectedMembers,
                  isExpanded: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: 'Stäng',
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
        ),
      ],
    );
  }

  Widget _buildMemberListTile(String userId, String userName, SharedListPermission permission, bool isOwner) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        userName,
        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: isOwner 
          ? Text('Ägare', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryBlue))
          : DropdownButton<SharedListPermission>(
              value: permission,
              onChanged: _isLoading ? null : (newPermission) {
                if (newPermission != null) {
                  _updateMemberPermission(userId, newPermission);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: SharedListPermission.view,
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: AppDimensions.iconSizeS, color: AppColors.textMedium),
                      SizedBox(width: AppDimensions.spacingXs),
                      Text('Kan se'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SharedListPermission.edit,
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: AppDimensions.iconSizeS, color: AppColors.accent),
                      SizedBox(width: AppDimensions.spacingXs),
                      Text('Kan redigera'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SharedListPermission.admin,
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: AppDimensions.iconSizeS, color: AppColors.primaryBlue),
                      SizedBox(width: AppDimensions.spacingXs),
                      Text('Admin'),
                    ],
                  ),
                ),
              ],
            ),
      trailing: !isOwner ? IconButton(
        onPressed: _isLoading ? null : () => _removeMember(userId, userName),
        icon: const Icon(Icons.person_remove, color: AppColors.error),
        tooltip: 'Ta bort medlem',
      ) : null,
    );
  }

  Widget _buildFriendListTile(UserProfile friend) {
    final isSelected = _selectedFriends.contains(friend.uid);
    
    return CheckboxListTile(
      secondary: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
        child: Text(
          friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        friend.displayName,
        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Läggs till med redigeringsbehörighet',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMedium,
        ),
      ),
      value: isSelected,
      onChanged: (selected) {
        setState(() {
          if (selected == true) {
            _selectedFriends.add(friend.uid);
          } else {
            _selectedFriends.remove(friend.uid);
          }
        });
      },
    );
  }
}