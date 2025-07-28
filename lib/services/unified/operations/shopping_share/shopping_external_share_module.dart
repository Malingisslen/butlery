// lib/services/unified/operations/shopping_share/shopping_external_share_module.dart

// ✅ PHASE 1A COMPLETED: All direct FirebaseFirestore.instance calls converted to use FirestoreRepository
// 🔄 PHASE 2 TODO: Further refactor to use specialized SocialSharingRepository for better domain separation

import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/unified/operations/shopping_share/shopping_export_module.dart';
import 'package:butlery/services/unified/operations/shopping_share/shared/shopping_share_utils.dart';

/// Shopping list external sharing module
/// 
/// This module handles ONLY external sharing operations:
/// - Share via external apps (using share_plus)
/// - Create public links for sharing
/// - Manage public sharing settings
/// - Handle external sharing validation
/// 
/// ❌ DOES NOT CONTAIN: Social sharing, templates, import, export formatting
class ShoppingExternalShareModule {
  final dynamic _parent; // UnifiedShoppingService
  final ShoppingExportModule _exportModule;
  late final FirestoreRepository _firestoreRepository;

  ShoppingExternalShareModule(this._parent) 
      : _exportModule = ShoppingExportModule(_parent) {
    _firestoreRepository = sl<FirestoreRepository>();
  }

  // ===== EXTERNAL APP SHARING =====

  /// Share shopping list via external apps
  Future<bool> shareList({
    required String listId,
    String format = 'text',
    String? customMessage,
  }) async {
    try {
      final list = _getListById(listId);
      final errorMessage = ShoppingShareUtils.validateListExists(list);
      if (errorMessage != null) {
        AppLogger.error('Cannot share: $errorMessage');
        return false;
      }
      
      if (!_exportModule.isValidExportFormat(format)) {
        AppLogger.error('Invalid export format: $format');
        return false;
      }
      
      String shareContent;
      
      switch (format) {
        case 'minimal':
          shareContent = _exportModule.exportListAsMinimalText(listId);
          break;
        case 'text':
        default:
          shareContent = _exportModule.exportListAsText(listId);
          break;
      }
      
      if (customMessage != null) {
        shareContent = '$customMessage\n\n$shareContent';
      }
      
      // Use share_plus plugin to share externally
      await Share.share(
        shareContent,
        subject: 'Inköpslista: ${list!.name}',
      );
      
      AppLogger.success('✅ List shared externally: ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share list', e);
      return false;
    }
  }

  /// Share shopping list with file attachment
  Future<bool> shareListAsFile({
    required String listId,
    required String format,
    String? customMessage,
  }) async {
    try {
      final list = _getListById(listId);
      final errorMessage = ShoppingShareUtils.validateListExists(list);
      if (errorMessage != null) {
        AppLogger.error('Cannot share file: $errorMessage');
        return false;
      }

      if (!_exportModule.isValidExportFormat(format)) {
        AppLogger.error('Invalid export format for file: $format');
        return false;
      }

      // For now, share as text - could be enhanced to create actual files
      return await shareList(
        listId: listId,
        format: format,
        customMessage: customMessage,
      );
    } catch (e) {
      AppLogger.error('Failed to share list as file', e);
      return false;
    }
  }

  // ===== PUBLIC LINK SHARING =====

  /// Create public link for shopping list
  Future<String?> createPublicLink(String listId, {
    Duration? expirationDuration,
  }) async {
    try {
      final list = _getListById(listId);
      final errorMessage = ShoppingShareUtils.validateListExists(list);
      if (errorMessage != null) {
        AppLogger.error('Cannot create link: $errorMessage');
        return null;
      }
      
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to create public link');
        return null;
      }
      
      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return null;
      
      // Create public sharing entry in Firestore
      final firestore = _firestoreRepository.firestore;
      final publicShareDoc = firestore.collection('publicShoppingLists').doc();
      
      final expirationDate = DateTime.now().add(
        expirationDuration ?? const Duration(days: 7)
      );
      
      await publicShareDoc.set({
        'listId': listId,
        'listName': list!.name,
        'ownerId': currentUser.uid,
        'ownerDisplayName': currentUser.displayName,
        'listData': _createPublicListData(list),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expirationDate),
        'isActive': true,
        'viewCount': 0,
        'settings': {
          'allowDownload': true,
          'showOwnerInfo': true,
          'showStatistics': true,
        },
      });
      
      final publicLink = 'https://butlery.app/shared/${publicShareDoc.id}';
      AppLogger.success('✅ Public link created for list: ${list.name}');
      return publicLink;
    } catch (e) {
      AppLogger.error('Failed to create public link', e);
      return null;
    }
  }

  /// Update public link settings
  Future<bool> updatePublicLinkSettings(
    String publicLinkId, {
    bool? allowDownload,
    bool? showOwnerInfo,
    bool? showStatistics,
    Duration? newExpiration,
  }) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to update public link');
        return false;
      }

      final firestore = _firestoreRepository.firestore;
      final updateData = <String, dynamic>{};

      if (allowDownload != null) {
        updateData['settings.allowDownload'] = allowDownload;
      }
      if (showOwnerInfo != null) {
        updateData['settings.showOwnerInfo'] = showOwnerInfo;
      }
      if (showStatistics != null) {
        updateData['settings.showStatistics'] = showStatistics;
      }
      if (newExpiration != null) {
        updateData['expiresAt'] = Timestamp.fromDate(
          DateTime.now().add(newExpiration)
        );
      }

      if (updateData.isNotEmpty) {
        await firestore
            .collection('publicShoppingLists')
            .doc(publicLinkId)
            .update(updateData);
        
        AppLogger.success('✅ Public link settings updated');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Failed to update public link settings', e);
      return false;
    }
  }

  /// Deactivate public link
  Future<bool> deactivatePublicLink(String publicLinkId) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to deactivate public link');
        return false;
      }

      final firestore = _firestoreRepository.firestore;
      await firestore
          .collection('publicShoppingLists')
          .doc(publicLinkId)
          .update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.success('✅ Public link deactivated');
      return true;
    } catch (e) {
      AppLogger.error('Failed to deactivate public link', e);
      return false;
    }
  }

  /// Get public links created by current user
  Future<List<Map<String, dynamic>>> getMyPublicLinks() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestoreRepository.firestore
          .collection('publicShoppingLists')
          .where('ownerId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'listName': data['listName'] ?? 'Namnlös lista',
          'url': 'https://butlery.app/shared/${doc.id}',
          'createdAt': data['createdAt'],
          'expiresAt': data['expiresAt'],
          'isActive': data['isActive'] ?? false,
          'viewCount': data['viewCount'] ?? 0,
          'settings': data['settings'] ?? {},
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get public links', e);
      return [];
    }
  }

  // ===== SHARING VALIDATION =====

  /// Validate sharing requirements
  bool canShareExternally(String listId) {
    final list = _getListById(listId);
    return list != null && list.items.isNotEmpty;
  }

  /// Get sharing restrictions for list
  Map<String, dynamic> getSharingRestrictions(String listId) {
    final list = _getListById(listId);
    if (list == null) {
      return {
        'canShare': false,
        'reason': 'Lista hittades inte',
      };
    }

    if (list.items.isEmpty) {
      return {
        'canShare': false,
        'reason': 'Tom lista kan inte delas',
      };
    }

    return {
      'canShare': true,
      'availableFormats': _exportModule.getAvailableExportFormats(),
    };
  }

  // ===== HELPER METHODS =====

  /// Get list by ID from parent service
  UnifiedShoppingList? _getListById(String listId) {
    return _parent.lists.where((list) => list.id == listId).firstOrNull;
  }

  /// Create public list data for sharing
  Map<String, dynamic> _createPublicListData(UnifiedShoppingList list) {
    return {
      'name': list.name,
      'description': list.description,
      'items': list.items.map((item) => {
        'name': item.name,
        'amount': item.amount,
        'unit': item.unit,
        'category': item.category,
        'bought': item.bought,
      }).toList(),
      'statistics': ShoppingShareUtils.getListStatistics(list),
    };
  }
}