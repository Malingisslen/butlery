// lib/views/social/group_content_feed/group_content_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Group Content App Bar - Styled app bar for group content feed
class GroupContentAppBar {
  static Widget build(
    BuildContext context, 
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          group.displayName,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryBlue.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40), // Space for back button
                Row(
                  children: [
                    if (group.emoji != null && group.emoji!.isNotEmpty) ...[
                      Text(
                        group.emoji!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppDimensions.spacingS),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (group.description != null && group.description!.isNotEmpty)
                            Text(
                              group.description!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.onPrimary.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildContentStats(viewModel),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: viewModel.refresh,
          tooltip: 'Uppdatera',
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, viewModel, group),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share_to_group',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('Dela till grupp'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'group_settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Gruppinställningar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'export_content',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Exportera innehåll'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildContentStats(GroupContentViewModel viewModel) {
    final stats = viewModel.groupContentStats;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stats['totalContent']}',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'delade',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  static void _handleMenuAction(
    BuildContext context,
    String action,
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) {
    switch (action) {
      case 'share_to_group':
        _showShareToGroupDialog(context, viewModel, group);
        break;
      case 'group_settings':
        Navigator.pushNamed(
          context,
          '/group-detail',
          arguments: {'groupId': group.id},
        );
        break;
      case 'export_content':
        _exportGroupContent(context, viewModel, group);
        break;
    }
  }

  static void _showShareToGroupDialog(
    BuildContext context,
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dela till ${group.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('Dela recept'),
              subtitle: const Text('Dela dina favoritrecept med gruppen'),
              onTap: () {
                Navigator.pop(context);
                _shareContentToGroup(context, 'recipe', group);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Dela meny'),
              subtitle: const Text('Dela en veckomeny med gruppen'),
              onTap: () {
                Navigator.pop(context);
                _shareContentToGroup(context, 'menu', group);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Dela inköpslista'),
              subtitle: const Text('Dela en inköpslista med gruppen'),
              onTap: () {
                Navigator.pop(context);
                _shareContentToGroup(context, 'shopping', group);
              },
            ),
            
            const SizedBox(height: AppDimensions.spacingM),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
          ],
        ),
      ),
    );
  }
  
  static void _shareContentToGroup(BuildContext context, String contentType, FriendCategory group) {
    switch (contentType) {
      case 'recipe':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receptdelning med ${group.name} kommer snart!'),
            backgroundColor: AppColors.info,
          ),
        );
        break;
      case 'menu':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menydelning med ${group.name} kommer snart!'),
            backgroundColor: AppColors.info,
          ),
        );
        break;
      case 'shopping':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Listdelning med ${group.name} kommer snart!'),
            backgroundColor: AppColors.info,
          ),
        );
        break;
    }
  }

  static Future<void> _exportGroupContent(
    BuildContext context,
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exportera ${group.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Exportera som text'),
              subtitle: const Text('Kopiera allt innehåll som text'),
              onTap: () {
                Navigator.pop(context);
                _exportAsText(context, viewModel, group);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Dela gruppsammanfattning'),
              subtitle: const Text('Skapa en delbar sammanfattning'),
              onTap: () {
                Navigator.pop(context);
                _shareGroupSummary(context, viewModel, group);
              },
            ),
            
            const SizedBox(height: AppDimensions.spacingM),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
          ],
        ),
      ),
    );
  }
  
  static Future<void> _exportAsText(BuildContext context, GroupContentViewModel viewModel, FriendCategory group) async {
    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('👥 ${group.name}');
      buffer.writeln('=' * (group.name.length + 2));
      buffer.writeln();
      
      if (group.description?.isNotEmpty == true) {
        buffer.writeln(group.description);
        buffer.writeln();
      }
      
      // Add group statistics
      buffer.writeln('📊 Gruppstatistik:');
      buffer.writeln('- Medlemmar: ${group.friendCount} personer');
      buffer.writeln('- Recept: ${viewModel.filteredGroupRecipes.length} delade');
      buffer.writeln('- Inköpslistor: ${viewModel.filteredGroupShoppingLists.length} delade');
      buffer.writeln();
      
      // Add recent activity summary
      buffer.writeln('📈 Senaste aktivitet:');
      buffer.writeln('Gruppens innehåll och aktivitet exporterad via Butlery');
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gruppinnehåll kopierat till urklipp!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte exportera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
  static void _shareGroupSummary(BuildContext context, GroupContentViewModel viewModel, FriendCategory group) {
    // Create a shareable summary
    final summary = '👥 Kolla in gruppen "${group.name}" på Butlery!\n\n'
        '🍳 ${viewModel.filteredGroupRecipes.length} delade recept\n'
        '🛍️ ${viewModel.filteredGroupShoppingLists.length} inköpslistor\n'
        '👤 ${group.friendCount} medlemmar\n\n'
        'Gå med i vår matcommunity! 🍽️';
    
    Clipboard.setData(ClipboardData(text: summary));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gruppsammanfattning kopierad! Klistra in för att dela.'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}