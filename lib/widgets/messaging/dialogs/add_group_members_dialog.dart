import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// Dialog for selecting friends to add to a group conversation.
class AddGroupMembersDialog extends StatefulWidget {
  final List<UserProfile> availableFriends;

  const AddGroupMembersDialog({
    super.key,
    required this.availableFriends,
  });

  /// Shows the dialog and returns the selected friends, or null if cancelled.
  static Future<List<UserProfile>?> show(
    BuildContext context,
    List<UserProfile> availableFriends,
  ) {
    return showDialog<List<UserProfile>>(
      context: context,
      builder: (context) =>
          AddGroupMembersDialog(availableFriends: availableFriends),
    );
  }

  @override
  State<AddGroupMembersDialog> createState() => _AddGroupMembersDialogState();
}

class _AddGroupMembersDialogState extends State<AddGroupMembersDialog> {
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _filteredFriends = widget.availableFriends;
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFriends);
    _searchController.dispose();
    super.dispose();
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = widget.availableFriends;
      } else {
        _filteredFriends = widget.availableFriends
            .where((f) => f.displayName.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chatAddMembers),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            ButlerySearchBox(
              controller: _searchController,
              hintText: context.l10n.chatSearchFriends,
            ),
            const SizedBox(height: AppDimensions.space8),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredFriends.length,
                itemBuilder: (context, index) {
                  final friend = _filteredFriends[index];
                  final isSelected = _selectedIds.contains(friend.uid);

                  return ButleryCheckboxTile(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedIds.add(friend.uid);
                        } else {
                          _selectedIds.remove(friend.uid);
                        }
                      });
                    },
                    title: Text(friend.displayName),
                    secondary: UserDisplayWidgets.avatar(
                      imageUrl: friend.avatarUrl,
                      displayName: friend.displayName,
                      size: ImageSize.small,
                      announceName: false,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.availableFriends
                      .where((f) => _selectedIds.contains(f.uid))
                      .toList();
                  Navigator.pop(context, selected);
                },
          child: Text(context.l10n.chatAddCount(_selectedIds.length)),
        ),
      ],
    );
  }
}
