// lib/widgets/common/avatar_circle.dart

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/indicators/emoji_avatar.dart';
import 'package:butlery/widgets/common/user_avatar.dart';

/// How big a person is drawn. The sketch draws people in lists at
/// 28–34 px and keeps the large circle for the head of a profile, so a
/// view picks a step here instead of a pixel size.
enum AvatarCircleSize {
  /// Beside a line of text: "Delat av", an assignee.
  inline(26),

  /// The leading circle of a list row.
  row(32),

  /// The head of a profile.
  header(56)
  ;

  const AvatarCircleSize(this.pixels);

  final double pixels;
}

/// What the circle sits on: the ink circle on paper, a paper circle on a
/// raised card, or a raised circle on an ink band.
enum AvatarCircleTone { ink, paper, onInk }

/// The one round avatar: a person (image, else initials on ink) or, with
/// [glyph], a group or other thing drawn as an emoji on paper.
class AvatarCircle extends StatelessWidget {
  final String displayName;
  final String? imageUrl;
  final AvatarCircleSize size;

  /// An emoji, or a short text such as "+3", drawn instead of a person;
  /// [displayName] is then unused.
  final String? glyph;

  /// Read the name aloud. Pass false where the name is visible beside the
  /// avatar in the same node, which would read it twice.
  final bool announceName;
  final VoidCallback? onTap;

  final AvatarCircleTone tone;

  const AvatarCircle({
    super.key,
    this.displayName = '',
    this.imageUrl,
    this.size = AvatarCircleSize.row,
    this.glyph,
    this.announceName = false,
    this.onTap,
    this.tone = AvatarCircleTone.ink,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (glyph != null) {
      return ExcludeSemantics(
        child: EmojiAvatar(
          emoji: glyph!,
          size: size.pixels,
          fontSize: size.pixels / 2,
        ),
      );
    }
    return UserAvatar(
      imageUrl: imageUrl,
      displayName: displayName,
      explicitSize: size.pixels,
      round: true,
      announceName: announceName,
      onTap: onTap,
      backgroundColor: switch (tone) {
        AvatarCircleTone.ink => null,
        AvatarCircleTone.paper => cs.surface,
        AvatarCircleTone.onInk => AppModeColors.surfaceRaisedOnInk(),
      },
      textColor: switch (tone) {
        AvatarCircleTone.ink => null,
        AvatarCircleTone.paper => cs.onSurface,
        AvatarCircleTone.onInk => cs.onPrimary,
      },
    );
  }
}
