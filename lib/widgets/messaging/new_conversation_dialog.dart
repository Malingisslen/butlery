// lib/widgets/messaging/new_conversation_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/messaging/create_group_conversation_view.dart';

/// Styled dialog for creating new conversations
class NewConversationDialog extends StatefulWidget {
  final Function(String conversationId) onConversationCreated;

  const NewConversationDialog({
    super.key,
    required this.onConversationCreated,
  });

  @override
  State<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<NewConversationDialog> {
  final TextEditingController _searchController = TextEditingController();
  
  late final UnifiedFriendsService _friendsService;
  late final MessagingService _messagingService;
  
  List<UserProfile> _friends = [];
  List<UserProfile> _filteredFriends = [];
  final List<String> _selectedFriendIds = [];
  bool _isCreating = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _friendsService = ServiceLocator.get<UnifiedFriendsService>();
    _messagingService = ServiceLocator.get<MessagingService>();
    _loadFriends();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFriends);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      // Get friends from the unified friends service
      final friends = _friendsService.friends;
      
      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredFriends = _friends;
        } else {
          _filteredFriends = _friends.where((friend) {
            return friend.displayName.toLowerCase().contains(query) ||
                   friend.email.toLowerCase().contains(query);
          }).toList();
        }
      });
    }
  }

  void _navigateToGroupCreation() {
    // Close current dialog
    Navigator.of(context).pop();

    // Navigate to group creation view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateGroupConversationView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ny konversation'),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          children: [
            // Quick action button for group creation
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
              child: OutlinedButton.icon(
                onPressed: _navigateToGroupCreation,
                icon: const Icon(Icons.group_add),
                label: const Text('Skapa gruppkonversation'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.paddingM,
                  ),
                ),
              ),
            ),

            const Divider(),
            const SizedBox(height: AppDimensions.paddingS),

            // Or select friend for direct chat
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Eller välj en vän för direktmeddelande:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            _buildSearchField(),
            const SizedBox(height: AppDimensions.paddingM),

            Expanded(
              child: _buildFriendsList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        StyledButton.primary(
          text: 'Skapa',
          onPressed: _selectedFriendIds.isEmpty || _isCreating
              ? null
              : _createConversation,
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Sök vänner...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
      ),
    );
  }

  /// Friends list with actual friends from the friends service
  /// 
  /// ✅ FIXED: Integrated with existing friends system
  Widget _buildFriendsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_friends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: AppDimensions.iconSizeXxl,
              color: AppColors.textMedium,
            ),
            SizedBox(height: AppDimensions.paddingM),
            Text(
              'Inga vänner ännu',
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 16,
              ),
            ),
            SizedBox(height: AppDimensions.paddingS),
            Text(
              'Lägg till vänner först för att starta konversationer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      return const Center(
        child: Text(
          'Inga vänner matchar din sökning',
          style: TextStyle(
            color: AppColors.textMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = _filteredFriends[index];
        final isSelected = _selectedFriendIds.contains(friend.uid);

        return CheckboxListTile(
          key: ValueKey(friend.uid),
          title: Text(friend.displayName),
          subtitle: Text(friend.email),
          value: isSelected,
          onChanged: (bool? selected) {
            if (mounted) {
              setState(() {
                if (selected == true) {
                  _selectedFriendIds.add(friend.uid);
                } else {
                  _selectedFriendIds.remove(friend.uid);
                }
              });
            }
          },
          secondary: CircleAvatar(
            child: Text(
              friend.displayName.isNotEmpty 
                  ? friend.displayName[0].toUpperCase()
                  : '?',
            ),
          ),
        );
      },
    );
  }

  /// Create conversation with selected friends
  /// 
  /// ✅ FIXED: Implemented actual conversation creation with friends system integration
  Future<void> _createConversation() async {
    if (_selectedFriendIds.isEmpty || _isCreating) return;

    if (mounted) {
      setState(() {
        _isCreating = true;
      });
    }

    try {
      String? conversationId;
      
      if (_selectedFriendIds.length == 1) {
        // Create direct conversation with single friend
        final friend = _friends.firstWhere((f) => f.uid == _selectedFriendIds.first);
        conversationId = await _messagingService.startDirectConversation(
          otherUserId: friend.uid,
          otherUserDisplayName: friend.displayName,
        );
      } else {
        // Create group conversation with multiple friends
        final selectedFriends = _friends.where((f) => _selectedFriendIds.contains(f.uid)).toList();
        final participantIds = _selectedFriendIds.toList();
        
        // Build participant maps for group conversation
        final participantDisplayNames = <String, String>{};
        final participantAvatarUrls = <String, String?>{};
        
        for (final friend in selectedFriends) {
          participantDisplayNames[friend.uid] = friend.displayName;
          participantAvatarUrls[friend.uid] = friend.avatarUrl;
        }
        
        conversationId = await _messagingService.createGroupConversation(
          participantIds: participantIds,
          participantDisplayNames: participantDisplayNames,
          participantAvatarUrls: participantAvatarUrls,
          title: 'Gruppchatt med ${selectedFriends.map((f) => f.displayName).join(', ')}',
        );
      }
      
      if (conversationId.isNotEmpty) {
        widget.onConversationCreated(conversationId);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte skapa konversation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}