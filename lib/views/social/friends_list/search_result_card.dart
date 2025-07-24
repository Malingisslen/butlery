// lib/views/social/friends_list/search_result_card.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/content_card.dart';

/// SearchResultCard - Search result card component
///
/// Displays search result user with add friend functionality.
class SearchResultCard {
  static Widget build(
    BuildContext context,
    UserProfile user,
    FriendsViewModel viewModel,
  ) {

    return ContentCard.friend(
      user: user,
    );
  }


}