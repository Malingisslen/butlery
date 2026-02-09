/// Platform-adaptive icon widget.
/// Uses SF Symbols (CupertinoIcons) on iOS for a native feel,
/// Material Icons on Android.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// A platform-adaptive icon that uses SF Symbols on iOS and Material Icons on Android.
///
/// Use named constructors for common icons to ensure consistent mapping:
/// ```dart
/// AdaptiveIcon.book()      // book icon
/// AdaptiveIcon.add()       // add/plus icon
/// AdaptiveIcon.calendar()  // calendar icon
/// AdaptiveIcon.cart()      // shopping cart icon
/// AdaptiveIcon.explore()   // explore/compass icon
/// ```
///
/// For custom icon pairs, use the default constructor:
/// ```dart
/// AdaptiveIcon(
///   materialIcon: Icons.custom,
///   cupertinoIcon: CupertinoIcons.custom,
/// )
/// ```
class AdaptiveIcon extends StatelessWidget {
  /// Creates an adaptive icon with explicit Material and Cupertino icons.
  const AdaptiveIcon({
    super.key,
    required this.materialIcon,
    this.cupertinoIcon,
    this.size,
    this.color,
    this.semanticLabel,
  });

  /// The Material Design icon to use on Android and web.
  final IconData materialIcon;

  /// The SF Symbol icon to use on iOS. Falls back to [materialIcon] if null.
  final IconData? cupertinoIcon;

  /// The size of the icon.
  final double? size;

  /// The color of the icon.
  final Color? color;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Whether we should use iOS icons.
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final iconData =
        _isIOS && cupertinoIcon != null ? cupertinoIcon! : materialIcon;
    return Icon(
      iconData,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }

  // ============================================================
  // Navigation Icons
  // ============================================================

  /// Book icon for recipes navigation.
  const AdaptiveIcon.book({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.book,
        cupertinoIcon = CupertinoIcons.book;

  /// Book outlined icon for inactive recipes navigation.
  const AdaptiveIcon.bookOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.book_outlined,
        cupertinoIcon = CupertinoIcons.book;

  /// Add/plus icon.
  const AdaptiveIcon.add({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.add,
        cupertinoIcon = CupertinoIcons.add;

  /// Add outlined icon.
  const AdaptiveIcon.addOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.add_outlined,
        cupertinoIcon = CupertinoIcons.add;

  /// Calendar icon for weekly menu.
  const AdaptiveIcon.calendar({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.calendar_today,
        cupertinoIcon = CupertinoIcons.calendar;

  /// Calendar outlined icon.
  const AdaptiveIcon.calendarOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.calendar_today_outlined,
        cupertinoIcon = CupertinoIcons.calendar;

  /// Shopping cart icon.
  const AdaptiveIcon.cart({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.shopping_cart,
        cupertinoIcon = CupertinoIcons.cart;

  /// Shopping cart outlined icon.
  const AdaptiveIcon.cartOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.shopping_cart_outlined,
        cupertinoIcon = CupertinoIcons.cart;

  /// Explore/compass icon for discovery.
  const AdaptiveIcon.explore({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.explore,
        cupertinoIcon = CupertinoIcons.compass;

  /// Explore outlined icon.
  const AdaptiveIcon.exploreOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.explore_outlined,
        cupertinoIcon = CupertinoIcons.compass;

  // ============================================================
  // Action Icons
  // ============================================================

  /// Share icon.
  const AdaptiveIcon.share({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.share,
        cupertinoIcon = CupertinoIcons.share;

  /// Delete/trash icon.
  const AdaptiveIcon.delete({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.delete,
        cupertinoIcon = CupertinoIcons.trash;

  /// Delete outlined icon.
  const AdaptiveIcon.deleteOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.delete_outline,
        cupertinoIcon = CupertinoIcons.trash;

  /// Edit/pencil icon.
  const AdaptiveIcon.edit({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.edit,
        cupertinoIcon = CupertinoIcons.pencil;

  /// Search icon.
  const AdaptiveIcon.search({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.search,
        cupertinoIcon = CupertinoIcons.search;

  /// More options (vertical ellipsis) icon.
  const AdaptiveIcon.moreVert({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.more_vert,
        cupertinoIcon = CupertinoIcons.ellipsis_vertical;

  /// More options (horizontal ellipsis) icon.
  const AdaptiveIcon.moreHoriz({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.more_horiz,
        cupertinoIcon = CupertinoIcons.ellipsis;

  /// Close/X icon.
  const AdaptiveIcon.close({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.close,
        cupertinoIcon = CupertinoIcons.xmark;

  /// Check/checkmark icon.
  const AdaptiveIcon.check({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.check,
        cupertinoIcon = CupertinoIcons.check_mark;

  /// Check circle icon.
  const AdaptiveIcon.checkCircle({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.check_circle,
        cupertinoIcon = CupertinoIcons.check_mark_circled;

  /// Settings/gear icon.
  const AdaptiveIcon.settings({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.settings,
        cupertinoIcon = CupertinoIcons.gear;

  // ============================================================
  // Social Icons
  // ============================================================

  /// People/friends icon.
  const AdaptiveIcon.people({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.people,
        cupertinoIcon = CupertinoIcons.person_2;

  /// People outlined icon.
  const AdaptiveIcon.peopleOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.people_outline,
        cupertinoIcon = CupertinoIcons.person_2;

  /// Person icon.
  const AdaptiveIcon.person({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.person,
        cupertinoIcon = CupertinoIcons.person;

  /// Person outlined icon.
  const AdaptiveIcon.personOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.person_outline,
        cupertinoIcon = CupertinoIcons.person;

  /// Group icon.
  const AdaptiveIcon.group({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.group,
        cupertinoIcon = CupertinoIcons.person_3;

  /// Group outlined icon.
  const AdaptiveIcon.groupOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.group_outlined,
        cupertinoIcon = CupertinoIcons.person_3;

  // ============================================================
  // Status/Feedback Icons
  // ============================================================

  /// Star/favorite icon.
  const AdaptiveIcon.star({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.star,
        cupertinoIcon = CupertinoIcons.star_fill;

  /// Star outlined icon.
  const AdaptiveIcon.starOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.star_border,
        cupertinoIcon = CupertinoIcons.star;

  /// Favorite/heart icon.
  const AdaptiveIcon.favorite({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.favorite,
        cupertinoIcon = CupertinoIcons.heart_fill;

  /// Favorite outlined icon.
  const AdaptiveIcon.favoriteOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.favorite_border,
        cupertinoIcon = CupertinoIcons.heart;

  /// Warning icon.
  const AdaptiveIcon.warning({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.warning,
        cupertinoIcon = CupertinoIcons.exclamationmark_triangle;

  /// Error icon.
  const AdaptiveIcon.error({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.error,
        cupertinoIcon = CupertinoIcons.exclamationmark_circle;

  /// Info icon.
  const AdaptiveIcon.info({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.info,
        cupertinoIcon = CupertinoIcons.info;

  /// Info outlined icon.
  const AdaptiveIcon.infoOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.info_outline,
        cupertinoIcon = CupertinoIcons.info;

  // ============================================================
  // Content Icons
  // ============================================================

  /// Restaurant/food icon.
  const AdaptiveIcon.restaurant({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.restaurant,
        cupertinoIcon =
            CupertinoIcons.photo; // No direct equivalent, using photo

  /// Camera icon.
  const AdaptiveIcon.camera({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.camera_alt,
        cupertinoIcon = CupertinoIcons.camera;

  /// Photo/image icon.
  const AdaptiveIcon.photo({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.photo,
        cupertinoIcon = CupertinoIcons.photo;

  /// Copy icon.
  const AdaptiveIcon.copy({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.copy,
        cupertinoIcon = CupertinoIcons.doc_on_doc;

  /// Refresh icon.
  const AdaptiveIcon.refresh({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.refresh,
        cupertinoIcon = CupertinoIcons.refresh;

  /// Sync icon.
  const AdaptiveIcon.sync({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.sync,
        cupertinoIcon = CupertinoIcons.arrow_2_circlepath;

  /// Exit/logout icon.
  const AdaptiveIcon.exitToApp({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.exit_to_app,
        cupertinoIcon = CupertinoIcons.square_arrow_right;

  /// Visibility/eye icon.
  const AdaptiveIcon.visibility({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.visibility,
        cupertinoIcon = CupertinoIcons.eye;

  /// Visibility off icon.
  const AdaptiveIcon.visibilityOff({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.visibility_off,
        cupertinoIcon = CupertinoIcons.eye_slash;

  /// Bookmark icon.
  const AdaptiveIcon.bookmark({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.bookmark,
        cupertinoIcon = CupertinoIcons.bookmark_fill;

  /// Bookmark outlined icon.
  const AdaptiveIcon.bookmarkOutlined({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.bookmark_border,
        cupertinoIcon = CupertinoIcons.bookmark;

  // ============================================================
  // Navigation/Arrow Icons
  // ============================================================

  /// Arrow back icon.
  const AdaptiveIcon.arrowBack({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.arrow_back,
        cupertinoIcon = CupertinoIcons.back;

  /// Arrow forward icon.
  const AdaptiveIcon.arrowForward({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.arrow_forward,
        cupertinoIcon = CupertinoIcons.forward;

  /// Chevron right icon.
  const AdaptiveIcon.chevronRight({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.chevron_right,
        cupertinoIcon = CupertinoIcons.chevron_right;

  /// Chevron left icon.
  const AdaptiveIcon.chevronLeft({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.chevron_left,
        cupertinoIcon = CupertinoIcons.chevron_left;

  /// Expand more (down arrow) icon.
  const AdaptiveIcon.expandMore({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.expand_more,
        cupertinoIcon = CupertinoIcons.chevron_down;

  /// Expand less (up arrow) icon.
  const AdaptiveIcon.expandLess({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : materialIcon = Icons.expand_less,
        cupertinoIcon = CupertinoIcons.chevron_up;
}

/// Static helper to get the appropriate IconData for the current platform.
/// Useful when you need IconData directly (e.g., for BottomNavigationBarItem).
class AdaptiveIcons {
  AdaptiveIcons._();

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // Navigation
  static IconData get book => _isIOS ? CupertinoIcons.book : Icons.book;
  static IconData get bookOutlined =>
      _isIOS ? CupertinoIcons.book : Icons.book_outlined;
  // UI Redesign: Grid icon for recipes navigation per mockup
  static IconData get grid =>
      _isIOS ? CupertinoIcons.square_grid_2x2 : Icons.grid_view;
  static IconData get gridOutlined =>
      _isIOS ? CupertinoIcons.square_grid_2x2 : Icons.grid_view_outlined;
  static IconData get add => _isIOS ? CupertinoIcons.add : Icons.add;
  static IconData get addOutlined =>
      _isIOS ? CupertinoIcons.add : Icons.add_outlined;
  static IconData get calendar =>
      _isIOS ? CupertinoIcons.calendar : Icons.calendar_today;
  static IconData get calendarOutlined =>
      _isIOS ? CupertinoIcons.calendar : Icons.calendar_today_outlined;
  static IconData get cart =>
      _isIOS ? CupertinoIcons.cart : Icons.shopping_cart;
  static IconData get cartOutlined =>
      _isIOS ? CupertinoIcons.cart : Icons.shopping_cart_outlined;
  static IconData get explore =>
      _isIOS ? CupertinoIcons.compass : Icons.explore;
  static IconData get exploreOutlined =>
      _isIOS ? CupertinoIcons.compass : Icons.explore_outlined;

  // Actions
  static IconData get share => _isIOS ? CupertinoIcons.share : Icons.share;
  static IconData get delete => _isIOS ? CupertinoIcons.trash : Icons.delete;
  static IconData get deleteOutlined =>
      _isIOS ? CupertinoIcons.trash : Icons.delete_outline;
  static IconData get edit => _isIOS ? CupertinoIcons.pencil : Icons.edit;
  static IconData get search => _isIOS ? CupertinoIcons.search : Icons.search;
  static IconData get moreVert =>
      _isIOS ? CupertinoIcons.ellipsis_vertical : Icons.more_vert;
  static IconData get moreHoriz =>
      _isIOS ? CupertinoIcons.ellipsis : Icons.more_horiz;
  static IconData get close => _isIOS ? CupertinoIcons.xmark : Icons.close;
  static IconData get check => _isIOS ? CupertinoIcons.check_mark : Icons.check;
  static IconData get checkCircle =>
      _isIOS ? CupertinoIcons.check_mark_circled : Icons.check_circle;
  static IconData get settings => _isIOS ? CupertinoIcons.gear : Icons.settings;

  // Social
  static IconData get people => _isIOS ? CupertinoIcons.person_2 : Icons.people;
  static IconData get peopleOutlined =>
      _isIOS ? CupertinoIcons.person_2 : Icons.people_outline;
  static IconData get person => _isIOS ? CupertinoIcons.person : Icons.person;
  static IconData get personOutlined =>
      _isIOS ? CupertinoIcons.person : Icons.person_outline;
  static IconData get group => _isIOS ? CupertinoIcons.person_3 : Icons.group;
  static IconData get groupOutlined =>
      _isIOS ? CupertinoIcons.person_3 : Icons.group_outlined;

  // Status
  static IconData get star => _isIOS ? CupertinoIcons.star_fill : Icons.star;
  static IconData get starOutlined =>
      _isIOS ? CupertinoIcons.star : Icons.star_border;
  static IconData get favorite =>
      _isIOS ? CupertinoIcons.heart_fill : Icons.favorite;
  static IconData get favoriteOutlined =>
      _isIOS ? CupertinoIcons.heart : Icons.favorite_border;
  static IconData get warning =>
      _isIOS ? CupertinoIcons.exclamationmark_triangle : Icons.warning;
  static IconData get error =>
      _isIOS ? CupertinoIcons.exclamationmark_circle : Icons.error;
  static IconData get info => _isIOS ? CupertinoIcons.info : Icons.info;
  static IconData get infoOutlined =>
      _isIOS ? CupertinoIcons.info : Icons.info_outline;

  // Content
  static IconData get restaurant =>
      _isIOS ? CupertinoIcons.photo : Icons.restaurant;
  static IconData get camera =>
      _isIOS ? CupertinoIcons.camera : Icons.camera_alt;
  static IconData get photo => _isIOS ? CupertinoIcons.photo : Icons.photo;
  static IconData get copy => _isIOS ? CupertinoIcons.doc_on_doc : Icons.copy;
  static IconData get refresh =>
      _isIOS ? CupertinoIcons.refresh : Icons.refresh;
  static IconData get sync =>
      _isIOS ? CupertinoIcons.arrow_2_circlepath : Icons.sync;
  static IconData get exitToApp =>
      _isIOS ? CupertinoIcons.square_arrow_right : Icons.exit_to_app;
  static IconData get visibility =>
      _isIOS ? CupertinoIcons.eye : Icons.visibility;
  static IconData get visibilityOff =>
      _isIOS ? CupertinoIcons.eye_slash : Icons.visibility_off;
  static IconData get bookmark =>
      _isIOS ? CupertinoIcons.bookmark_fill : Icons.bookmark;
  static IconData get bookmarkOutlined =>
      _isIOS ? CupertinoIcons.bookmark : Icons.bookmark_border;

  // Navigation arrows
  static IconData get arrowBack =>
      _isIOS ? CupertinoIcons.back : Icons.arrow_back;
  static IconData get arrowForward =>
      _isIOS ? CupertinoIcons.forward : Icons.arrow_forward;
  static IconData get chevronRight =>
      _isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right;
  static IconData get chevronLeft =>
      _isIOS ? CupertinoIcons.chevron_left : Icons.chevron_left;
  static IconData get expandMore =>
      _isIOS ? CupertinoIcons.chevron_down : Icons.expand_more;
  static IconData get expandLess =>
      _isIOS ? CupertinoIcons.chevron_up : Icons.expand_less;
}
