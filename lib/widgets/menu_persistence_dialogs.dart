// lib/widgets/menu_persistence_dialogs.dart
// UPPDATERAD med Source Attribution och Social Import

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../viewmodels/menu_viewmodel.dart';
import '../theme/app_theme.dart';

/// Dialog för att spara en meny med namn, kommentar OCH social sharing
class SaveMenuDialog extends StatefulWidget {
  final MenuViewModel viewModel;
  final List<dynamic>? availableFriends; // För social sharing

  const SaveMenuDialog({
    required this.viewModel,
    this.availableFriends,
    super.key,
  });

  @override
  State<SaveMenuDialog> createState() => _SaveMenuDialogState();
}

class _SaveMenuDialogState extends State<SaveMenuDialog> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  final _shareMessageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _shareWithFriends = false;
  final Set<String> _selectedFriendIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _shareMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final success = await widget.viewModel.saveMenuWithNameAndComment(
        _nameController.text,
        _commentController.text,
        shareWithFriends: _shareWithFriends,
        selectedFriendIds:
            _shareWithFriends ? _selectedFriendIds.toList() : null,
        shareMessage:
            _shareWithFriends ? _shareMessageController.text.trim() : null,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);

          final message = _shareWithFriends
              ? 'Meny "${_nameController.text}" sparad och delad med ${_selectedFriendIds.length} vänner!'
              : 'Meny "${_nameController.text}" sparad!';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.viewModel.error ?? 'Kunde inte spara meny'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.save,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: AppTheme.spacingSm),
          const Text('Spara Veckomeny'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meny info
                _buildMenuInfo(),
                AppTheme.mediumGap,

                // Namn-fält
                _buildNameField(),
                AppTheme.mediumGap,

                // Kommentar-fält
                _buildCommentField(),
                AppTheme.mediumGap,

                // Social sharing toggle
                if (widget.availableFriends?.isNotEmpty == true) ...[
                  _buildSocialSharingToggle(),
                  if (_shareWithFriends) ...[
                    AppTheme.mediumGap,
                    _buildFriendSelection(),
                    AppTheme.mediumGap,
                    _buildShareMessage(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Avbryt'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveMenu,
          icon: _isSaving
              ? AppTheme.smallLoadingIndicator()
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Sparar...' : 'Spara'),
        ),
      ],
    );
  }

  Widget _buildMenuInfo() {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Row(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: AppTheme.iconSizeSmall,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              '${widget.viewModel.totalRecipeCount} recept i ${widget.viewModel.menu.length} kategorier',
              style: AppTheme.captionStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      enabled: !_isSaving,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Namn på meny *',
        hintText: 'Ex: Familj Vinter 2025',
        prefixIcon: Icon(Icons.edit),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value?.trim().isEmpty ?? true) {
          return 'Ange ett namn för menyn';
        }
        return null;
      },
      onFieldSubmitted: (_) => _saveMenu(),
    );
  }

  Widget _buildCommentField() {
    return TextFormField(
      controller: _commentController,
      enabled: !_isSaving,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Kommentar (valfritt)',
        hintText:
            'Ex: Perfekt för kalla vinterdagar, barnen älskar köttbullarna',
        prefixIcon: Icon(Icons.comment),
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildSocialSharingToggle() {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.share,
            color: Theme.of(context).colorScheme.primary,
            size: AppTheme.iconSizeAction,
          ),
          SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dela med vänner',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Dela menyn socialt med dina vänner samtidigt',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: _shareWithFriends,
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _shareWithFriends = value;
                      if (!value) {
                        _selectedFriendIds.clear();
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildFriendSelection() {
    final friends = widget.availableFriends ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Välj vänner att dela med:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingSm),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: AppTheme.mediumRadius,
          ),
          child: friends.isEmpty
              ? Center(
                  child: Text(
                    'Inga vänner tillgängliga',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final friendId = friend.uid;
                    final isSelected = _selectedFriendIds.contains(friendId);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedFriendIds.add(friendId);
                          } else {
                            _selectedFriendIds.remove(friendId);
                          }
                        });
                      },
                      title: Text(friend.displayName),
                      subtitle: friend.bio?.isNotEmpty == true
                          ? Text(
                              friend.bio!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                    );
                  },
                ),
        ),
        if (_selectedFriendIds.isNotEmpty) ...[
          SizedBox(height: AppTheme.spacingSm),
          Text(
            '${_selectedFriendIds.length} vän(ner) valda',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildShareMessage() {
    return TextFormField(
      controller: _shareMessageController,
      enabled: !_isSaving,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Delningsmeddelande (valfritt)',
        hintText: 'Ex: Här är min favoritveckomeny!',
        prefixIcon: Icon(Icons.message),
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}

/// Bottom sheet för att ladda en sparad meny MED source attribution
class LoadMenuBottomSheet extends StatelessWidget {
  final MenuViewModel viewModel;

  const LoadMenuBottomSheet({
    required this.viewModel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final savedMenus = viewModel.savedMenus;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.folder_open,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Sparade Menyer',
                style: AppTheme.sectionTitleStyle,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          AppTheme.mediumGap,

          // Lista över sparade menyer MED attribution
          if (savedMenus.isEmpty)
            _buildEmptyState(context)
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: savedMenus.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final menuInfo = savedMenus[index];
                  return _buildMenuListItem(context, menuInfo);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
      child: Column(
        children: [
          Icon(
            Icons.folder_off,
            size: AppTheme.iconSizeLarge,
            color: Theme.of(context).colorScheme.outline,
          ),
          AppTheme.mediumGap,
          Text(
            'Inga sparade menyer ännu',
            style: AppTheme.subtitleStyle.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          AppTheme.smallGap,
          Text(
            'Spara din första meny för att komma igång!',
            style: AppTheme.captionStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuListItem(BuildContext context, SavedMenuInfo menuInfo) {
    final dateFormat = DateFormat('d MMM yyyy', 'sv_SE');
    final formattedDate = dateFormat.format(menuInfo.savedDate);

    return ListTile(
      contentPadding: AppTheme.cardPadding,
      leading: CircleAvatar(
        backgroundColor: menuInfo.attributionColor.withValues(alpha: 0.1),
        child: Icon(
          menuInfo.statusIcon,
          color: menuInfo.attributionColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              menuInfo.name,
              style: AppTheme.subtitleStyle.copyWith(
                fontWeight:
                    menuInfo.isOwned ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          // Attribution badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: menuInfo.attributionColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
              border: Border.all(
                color: menuInfo.attributionColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              menuInfo.attribution,
              style: AppTheme.chipLabelStyle.copyWith(
                color: menuInfo.attributionColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppTheme.spacingXs),
          Text(
            'Sparad: $formattedDate • ${menuInfo.recipeCount} recept',
            style: AppTheme.captionStyle,
          ),
          if (menuInfo.comment.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingXs),
            Text(
              menuInfo.comment,
              style: AppTheme.captionStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Extra info för importerade menyer
          if (!menuInfo.isOwned && menuInfo.originalAuthor != null) ...[
            SizedBox(height: AppTheme.spacingXs),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 12,
                  color: menuInfo.attributionColor,
                ),
                SizedBox(width: AppTheme.spacingXs),
                Text(
                  'Ursprunglig författare: ${menuInfo.originalAuthor}',
                  style: AppTheme.captionStyle.copyWith(
                    color: menuInfo.attributionColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'load',
            child: Row(
              children: [
                const Icon(Icons.open_in_new),
                SizedBox(width: AppTheme.spacingSm),
                const Text('Ladda meny'),
              ],
            ),
          ),
          if (!menuInfo.isOwned) ...[
            PopupMenuItem(
              value: 'mark_modified',
              enabled: !menuInfo.isModified,
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high),
                  SizedBox(width: AppTheme.spacingSm),
                  const Text('Markera som modifierad'),
                ],
              ),
            ),
          ],
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: AppTheme.errorColor),
                SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Ta bort',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) => _handleMenuAction(context, menuInfo, value),
      ),
      onTap: () => _loadMenu(context, menuInfo),
    );
  }

  void _handleMenuAction(
      BuildContext context, SavedMenuInfo menuInfo, String action) {
    switch (action) {
      case 'load':
        _loadMenu(context, menuInfo);
        break;
      case 'mark_modified':
        _markAsModified(context, menuInfo);
        break;
      case 'delete':
        _confirmDeleteMenu(context, menuInfo);
        break;
    }
  }

  Future<void> _loadMenu(BuildContext context, SavedMenuInfo menuInfo) async {
    final success = await viewModel.loadSavedMenu(menuInfo.key);

    if (context.mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meny "${menuInfo.name}" laddad!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error ?? 'Kunde inte ladda meny'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _markAsModified(
      BuildContext context, SavedMenuInfo menuInfo) async {
    final success = await viewModel.markMenuAsModified(menuInfo.key);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meny "${menuInfo.name}" markerad som modifierad!'),
            backgroundColor: AppTheme.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                viewModel.error ?? 'Kunde inte markera meny som modifierad'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteMenu(
      BuildContext context, SavedMenuInfo menuInfo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort meny?'),
        content: Text('Vill du verkligen ta bort menyn "${menuInfo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final success = await viewModel.deleteSavedMenu(menuInfo.key);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Meny "${menuInfo.name}" borttagen'
                  : 'Kunde inte ta bort meny',
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
