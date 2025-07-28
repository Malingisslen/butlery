// lib/widgets/common/share_dialog/share_dialog_helpers.dart

import 'package:butlery/widgets/common/universal_share_dialog.dart';

class ShareDialogHelpers {
  static String getContentTypeName(ShareContentType contentType) {
    switch (contentType) {
      case ShareContentType.recipe:
        return 'recept';
      case ShareContentType.menu:
        return 'menyer';
      case ShareContentType.shoppingList:
        return 'inköpslistor';
    }
  }

  static String getShareButtonText(
    ShareContentType contentType,
    ShareMode selectedMode,
    bool supportsRealtimeSharing,
  ) {
    if (selectedMode == ShareMode.realtime && supportsRealtimeSharing) {
      return 'Skapa & Dela';
    } else {
      switch (contentType) {
        case ShareContentType.recipe:
          return 'Dela recept';
        case ShareContentType.menu:
          return 'Dela meny';
        case ShareContentType.shoppingList:
          return 'Dela inköpslista';
      }
    }
  }

  static bool supportsRealtimeSharing(ShareContentType contentType) {
    switch (contentType) {
      case ShareContentType.recipe:
      case ShareContentType.menu:
        return true;
      case ShareContentType.shoppingList:
        return false;
    }
  }

  static String getDefaultMessage(
    ShareContentType contentType,
    String contentName,
  ) {
    switch (contentType) {
      case ShareContentType.recipe:
        return 'Kolla in detta recept: $contentName';
      case ShareContentType.menu:
        return 'Kolla in denna veckomeny: $contentName';
      case ShareContentType.shoppingList:
        return 'Kolla in denna inköpslista: $contentName';
    }
  }

  static String getSuccessMessage(
    ShareContentType contentType,
    int recipientCount,
    ShareMode shareMode,
  ) {
    final contentName = getContentTypeName(contentType);
    final modeText = shareMode == ShareMode.realtime ? 'realtidsdelning' : 'kopia';
    
    return '$contentName har delats som $modeText med $recipientCount mottagare.';
  }

  static String getShareTitle(ShareContentType contentType) {
    switch (contentType) {
      case ShareContentType.recipe:
        return 'Dela recept med vänner';
      case ShareContentType.menu:
        return 'Dela veckomeny med vänner';
      case ShareContentType.shoppingList:
        return 'Dela inköpslista';
    }
  }

  static String formatSelectionSummary(
    int selectedCount,
    String contentTypeName,
  ) {
    if (selectedCount == 0) {
      return 'Välj minst en vän för att dela $contentTypeName';
    }
    return '$selectedCount vän${selectedCount > 1 ? 'ner' : ''} valda';
  }
}