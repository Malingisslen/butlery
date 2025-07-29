// lib/widgets/messaging/new_conversation_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/styled/styled_button.dart';

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
  
  // TODO: This should integrate with the existing friends system
  final List<String> _selectedFriends = [];
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ny konversation'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
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
          onPressed: _selectedFriends.isEmpty || _isCreating 
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

  Widget _buildFriendsList() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.textMedium,
          ),
          SizedBox(height: AppDimensions.paddingM),
          Text(
            'Vänner-systemet kommer snart!',
            style: TextStyle(
              color: AppColors.textMedium,
              fontSize: 16,
            ),
          ),
          SizedBox(height: AppDimensions.paddingS),
          Text(
            'Du kommer att kunna söka och välja vänner för att starta konversationer.',
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

  Future<void> _createConversation() async {
    if (_selectedFriends.isEmpty || _isCreating) return;

    setState(() {
      _isCreating = true;
    });

    try {
      // TODO: Implement actual conversation creation with selected friends
      // For now, this is a placeholder that would integrate with the friends system
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konversationskapande kommer när vänner-systemet är klart!'),
        ),
      );
      
      Navigator.of(context).pop();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}