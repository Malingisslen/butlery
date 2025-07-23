// lib/services/notifications/notification_templates.dart

/// Localized notification message templates for Butlery
/// 
/// Provides Swedish and English templates for all notification types
/// with variable substitution and context-aware messaging

class NotificationTemplates {
  static const Map<String, Map<String, String>> _templates = {
    // ===== FRIEND SYSTEM NOTIFICATIONS =====
    
    'friend_request_sent': {
      'title_sv': 'Vänskapsförfrågan skickad',
      'title_en': 'Friend request sent',
      'body_sv': 'Du skickade en vänskapsförfrågan till {recipientName}',
      'body_en': 'You sent a friend request to {recipientName}',
    },
    
    'friend_request_received': {
      'title_sv': 'Ny vänskapsförfrågan',
      'title_en': 'New friend request',
      'body_sv': '{senderName} vill bli vän med dig',
      'body_en': '{senderName} wants to be your friend',
    },
    
    'friend_request_accepted': {
      'title_sv': 'Vänskapsförfrågan accepterad',
      'title_en': 'Friend request accepted',
      'body_sv': '{accepterName} accepterade din vänskapsförfrågan',
      'body_en': '{accepterName} accepted your friend request',
    },
    
    'friend_request_declined': {
      'title_sv': 'Vänskapsförfrågan avvisad',
      'title_en': 'Friend request declined',
      'body_sv': '{declinerName} avvisade din vänskapsförfrågan',
      'body_en': '{declinerName} declined your friend request',
    },
    
    'friend_online': {
      'title_sv': 'Vän online',
      'title_en': 'Friend online',
      'body_sv': '{friendName} är nu online',
      'body_en': '{friendName} is now online',
    },
    
    'friend_joined_butlery': {
      'title_sv': 'Vän gick med i Butlery',
      'title_en': 'Friend joined Butlery',
      'body_sv': '{friendName} gick med i Butlery! Säg hej!',
      'body_en': '{friendName} joined Butlery! Say hello!',
    },

    // ===== RECIPE SHARING NOTIFICATIONS =====
    
    'recipe_shared_direct': {
      'title_sv': 'Recept delat med dig',
      'title_en': 'Recipe shared with you',
      'body_sv': '{senderName} delade "{recipeName}" med dig',
      'body_en': '{senderName} shared "{recipeName}" with you',
    },
    
    'recipe_shared_group': {
      'title_sv': 'Recept delat i grupp',
      'title_en': 'Recipe shared in group',
      'body_sv': '{senderName} delade "{recipeName}" i {groupName}',
      'body_en': '{senderName} shared "{recipeName}" in {groupName}',
    },
    
    'recipe_imported': {
      'title_sv': 'Ditt recept importerades',
      'title_en': 'Your recipe was imported',
      'body_sv': '{importerName} importerade ditt recept "{recipeName}"',
      'body_en': '{importerName} imported your recipe "{recipeName}"',
    },
    
    'recipe_liked': {
      'title_sv': 'Recept gillades',
      'title_en': 'Recipe liked',
      'body_sv': '{likerName} gillade ditt recept "{recipeName}"',
      'body_en': '{likerName} liked your recipe "{recipeName}"',
    },
    
    'recipe_liked_multiple': {
      'title_sv': 'Recept gillades',
      'title_en': 'Recipe liked',
      'body_sv': '{count} personer gillade ditt recept "{recipeName}"',
      'body_en': '{count} people liked your recipe "{recipeName}"',
    },

    // ===== RECIPE COMMENTS NOTIFICATIONS =====
    
    'recipe_comment_new': {
      'title_sv': 'Ny kommentar',
      'title_en': 'New comment',
      'body_sv': '{commenterName} kommenterade ditt recept "{recipeName}"',
      'body_en': '{commenterName} commented on your recipe "{recipeName}"',
    },
    
    'recipe_comment_reply': {
      'title_sv': 'Svar på kommentar',
      'title_en': 'Reply to comment',
      'body_sv': '{replierName} svarade på din kommentar i "{recipeName}"',
      'body_en': '{replierName} replied to your comment on "{recipeName}"',
    },
    
    'recipe_comments_multiple': {
      'title_sv': 'Nya kommentarer',
      'title_en': 'New comments',
      'body_sv': '{count} nya kommentarer på dina recept',
      'body_en': '{count} new comments on your recipes',
    },
    
    'recipe_comment_liked': {
      'title_sv': 'Kommentar gillades',
      'title_en': 'Comment liked',
      'body_sv': '{likerName} gillade din kommentar i "{recipeName}"',
      'body_en': '{likerName} liked your comment on "{recipeName}"',
    },

    // ===== COLLABORATION NOTIFICATIONS =====
    
    'collaboration_invite_recipe': {
      'title_sv': 'Inbjudan till receptsamarbete',
      'title_en': 'Recipe collaboration invite',
      'body_sv': '{inviterName} bjuder in dig att redigera "{recipeName}"',
      'body_en': '{inviterName} invited you to edit "{recipeName}"',
    },
    
    'collaboration_invite_menu': {
      'title_sv': 'Inbjudan till menysamarbete',
      'title_en': 'Menu collaboration invite',
      'body_sv': '{inviterName} bjuder in dig att redigera "{menuName}"',
      'body_en': '{inviterName} invited you to edit "{menuName}"',
    },
    
    'collaboration_started': {
      'title_sv': 'Samarbete påbörjat',
      'title_en': 'Collaboration started',
      'body_sv': '{starterName} började redigera "{resourceName}"',
      'body_en': '{starterName} started editing "{resourceName}"',
    },
    
    'collaboration_joined': {
      'title_sv': 'Någon gick med i samarbete',
      'title_en': 'Someone joined collaboration',
      'body_sv': '{joinerName} gick med i redigeringen av "{resourceName}"',
      'body_en': '{joinerName} joined editing "{resourceName}"',
    },
    
    'collaboration_edit_conflict': {
      'title_sv': 'Redigeringskonflikt',
      'title_en': 'Edit conflict',
      'body_sv': 'Konflikt upptäckt i "{resourceName}" - kontrollera dina ändringar',
      'body_en': 'Conflict detected in "{resourceName}" - please review your changes',
    },
    
    'collaboration_completed': {
      'title_sv': 'Samarbete avslutat',
      'title_en': 'Collaboration completed',
      'body_sv': 'Redigeringen av "{resourceName}" är klar',
      'body_en': 'Editing of "{resourceName}" is complete',
    },

    // ===== MENU PLANNING NOTIFICATIONS =====
    
    'menu_shared': {
      'title_sv': 'Veckomeny delad',
      'title_en': 'Weekly menu shared',
      'body_sv': '{sharerName} delade sin veckomeny med dig',
      'body_en': '{sharerName} shared their weekly menu with you',
    },
    
    'menu_plan_changed': {
      'title_sv': 'Menyplan ändrad',
      'title_en': 'Menu plan changed',
      'body_sv': '{changerName} ändrade den delade menyplanen',
      'body_en': '{changerName} changed the shared menu plan',
    },
    
    'menu_suggestion': {
      'title_sv': 'Menyförslag',
      'title_en': 'Menu suggestion',
      'body_sv': '{suggesterName} föreslog ändringar i din veckomeny',
      'body_en': '{suggesterName} suggested changes to your weekly menu',
    },
    
    'menu_ready': {
      'title_sv': 'Veckomeny redo',
      'title_en': 'Weekly menu ready',
      'body_sv': 'Din veckomeny för vecka {weekNumber} är redo!',
      'body_en': 'Your weekly menu for week {weekNumber} is ready!',
    },

    // ===== SHOPPING LIST NOTIFICATIONS =====
    
    'shopping_list_shared': {
      'title_sv': 'Inköpslista delad',
      'title_en': 'Shopping list shared',
      'body_sv': '{sharerName} delade inköpslistan "{listName}" med dig',
      'body_en': '{sharerName} shared shopping list "{listName}" with you',
    },
    
    'shopping_list_updated': {
      'title_sv': 'Inköpslista uppdaterad',
      'title_en': 'Shopping list updated',
      'body_sv': '{updaterName} uppdaterade "{listName}"',
      'body_en': '{updaterName} updated "{listName}"',
    },
    
    'shopping_item_completed': {
      'title_sv': 'Vara inhandlad',
      'title_en': 'Item purchased',
      'body_sv': '{buyerName} köpte {itemName}',
      'body_en': '{buyerName} bought {itemName}',
    },
    
    'shopping_list_completed': {
      'title_sv': 'Inköpslista klar',
      'title_en': 'Shopping list complete',
      'body_sv': 'Inköpslistan "{listName}" är nu klar!',
      'body_en': 'Shopping list "{listName}" is now complete!',
    },

    // ===== SOCIAL ACTIVITY NOTIFICATIONS =====
    
    'friend_cooked_recipe': {
      'title_sv': 'Vän lagade recept',
      'title_en': 'Friend cooked recipe',
      'body_sv': '{friendName} lagade "{recipeName}"',
      'body_en': '{friendName} cooked "{recipeName}"',
    },
    
    'friend_created_recipe': {
      'title_sv': 'Vän skapade recept',
      'title_en': 'Friend created recipe',
      'body_sv': '{friendName} skapade ett nytt recept: "{recipeName}"',
      'body_en': '{friendName} created a new recipe: "{recipeName}"',
    },
    
    'friend_achievement': {
      'title_sv': 'Vän nådde mål',
      'title_en': 'Friend achievement',
      'body_sv': '{friendName} nådde målet: {achievementName}',
      'body_en': '{friendName} achieved: {achievementName}',
    },

    // ===== DIGEST NOTIFICATIONS =====
    
    'daily_digest': {
      'title_sv': 'Dagens aktivitet',
      'title_en': 'Daily activity',
      'body_sv': 'Se vad dina vänner lagat idag - {activityCount} nya aktiviteter',
      'body_en': 'See what your friends cooked today - {activityCount} new activities',
    },
    
    'weekly_digest': {
      'title_sv': 'Veckans höjdpunkter',
      'title_en': 'Weekly highlights',
      'body_sv': 'Veckans populäraste recept och aktiviteter',
      'body_en': 'This week\'s most popular recipes and activities',
    },
    
    'recipe_recommendations': {
      'title_sv': 'Receptrekommendationer',
      'title_en': 'Recipe recommendations',
      'body_sv': 'Vi har {count} nya recept du kanske gillar',
      'body_en': 'We have {count} new recipes you might like',
    },

    // ===== SYSTEM NOTIFICATIONS =====
    
    'app_update_available': {
      'title_sv': 'App-uppdatering tillgänglig',
      'title_en': 'App update available',
      'body_sv': 'En ny version av Butlery är tillgänglig',
      'body_en': 'A new version of Butlery is available',
    },
    
    'maintenance_notice': {
      'title_sv': 'Underhåll schemalagt',
      'title_en': 'Maintenance scheduled',
      'body_sv': 'Butlery kommer vara otillgänglig {maintenanceTime}',
      'body_en': 'Butlery will be unavailable {maintenanceTime}',
    },
    
    'sync_completed': {
      'title_sv': 'Synkronisering klar',
      'title_en': 'Sync completed',
      'body_sv': 'Dina recept och data är nu synkroniserade',
      'body_en': 'Your recipes and data are now synchronized',
    },

    // ===== GROUP NOTIFICATIONS =====
    
    'group_invitation': {
      'title_sv': 'Gruppinbjudan',
      'title_en': 'Group invitation',  
      'body_sv': '{inviterName} bjöd in dig till gruppen "{groupName}"',
      'body_en': '{inviterName} invited you to group "{groupName}"',
    },
    
    'group_member_added': {
      'title_sv': 'Ny gruppmedlem',
      'title_en': 'New group member',
      'body_sv': '{newMemberName} gick med i gruppen "{groupName}"',
      'body_en': '{newMemberName} joined group "{groupName}"',
    },
    
    'group_activity': {
      'title_sv': 'Gruppaktivitet',
      'title_en': 'Group activity',
      'body_sv': 'Ny aktivitet i gruppen "{groupName}"',
      'body_en': 'New activity in group "{groupName}"',
    },
  };

  /// Get localized template for given key and language
  static String getTemplate(String key, String field, {String language = 'sv'}) {
    final template = _templates[key];
    if (template == null) {
      throw ArgumentError('Unknown notification template: $key');
    }

    final localeKey = '${field}_$language';
    final fallbackKey = '${field}_sv'; // Swedish as fallback
    
    return template[localeKey] ?? 
           template[fallbackKey] ?? 
           'Ny aktivitet i Butlery'; // Ultimate fallback
  }

  /// Substitute variables in template string
  static String substituteVariables(String template, Map<String, String> variables) {
    String result = template;
    
    variables.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    
    return result;
  }

  /// Get complete notification content with variable substitution
  static Map<String, String> getNotificationContent({
    required String templateKey,
    required Map<String, String> variables,
    String language = 'sv',
  }) {
    final title = getTemplate(templateKey, 'title', language: language);
    final body = getTemplate(templateKey, 'body', language: language);
    
    return {
      'title': substituteVariables(title, variables),
      'body': substituteVariables(body, variables),
    };
  }

  /// Get action button text for common actions
  static Map<String, String> getActionTexts({String language = 'sv'}) {
    final actions = {
      'accept': {'sv': 'Acceptera', 'en': 'Accept'},
      'decline': {'sv': 'Avvisa', 'en': 'Decline'},
      'view': {'sv': 'Visa', 'en': 'View'},
      'join': {'sv': 'Gå med', 'en': 'Join'},
      'ignore': {'sv': 'Ignorera', 'en': 'Ignore'},
      'reply': {'sv': 'Svara', 'en': 'Reply'},
      'like': {'sv': 'Gilla', 'en': 'Like'},
      'share': {'sv': 'Dela', 'en': 'Share'},
      'cook': {'sv': 'Laga', 'en': 'Cook'},
      'save': {'sv': 'Spara', 'en': 'Save'},
      'open': {'sv': 'Öppna', 'en': 'Open'},
      'settings': {'sv': 'Inställningar', 'en': 'Settings'},
    };

    return actions.map((key, translations) => 
      MapEntry(key, translations[language] ?? translations['sv']!));
  }

  /// Validate template key exists
  static bool hasTemplate(String key) {
    return _templates.containsKey(key);
  }

  /// Get all available template keys
  static List<String> getAllTemplateKeys() {
    return _templates.keys.toList();  
  }

  /// Get templates for specific category
  static List<String> getTemplatesForCategory(String category) {
    return _templates.keys
        .where((key) => key.startsWith(category))
        .toList();
  }

  /// Format count for Swedish pluralization
  static String formatCount(int count, String singular, String plural) {
    if (count == 1) {
      return '$count $singular';
    } else {
      return '$count $plural';
    }
  }

  /// Format time for Swedish locale
  static String formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just nu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  /// Create smart batched content for multiple similar notifications
  static Map<String, String> createBatchedContent({
    required String baseTemplateKey,
    required int count,
    required Map<String, String> variables,
    String language = 'sv',
  }) {
    // Create batched version of notification
    String batchedTemplateKey;
    
    if (baseTemplateKey.contains('comment') && count > 1) {
      batchedTemplateKey = 'recipe_comments_multiple';
    } else if (baseTemplateKey.contains('liked') && count > 1) {
      batchedTemplateKey = 'recipe_liked_multiple';
    } else {
      // Use original template for single items
      return getNotificationContent(
        templateKey: baseTemplateKey,
        variables: variables,
        language: language,
      );
    }

    final batchedVariables = Map<String, String>.from(variables);
    batchedVariables['count'] = count.toString();
    
    return getNotificationContent(
      templateKey: batchedTemplateKey,
      variables: batchedVariables,
      language: language,
    );
  }
}