// lib/views/photo_import/photo_permission_notice_card.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/permissions/media_permission_notice_card.dart';

/// The permission notice on photo import, per flow 07
/// [MediaPermissionNoticeCard] with
/// import's own words for a no and its fallbacks. No camera leads to the
/// library, no library leads to writing the recipe yourself
class PhotoPermissionNoticeCard extends StatelessWidget {
  const PhotoPermissionNoticeCard({
    super.key,
    required this.notice,
    required this.onAskAgain,
    required this.onOpenSettings,
    required this.onChooseFromGallery,
    required this.onWriteYourself,
  });

  final PhotoPermissionNotice notice;
  final VoidCallback onAskAgain;
  final VoidCallback onOpenSettings;
  final VoidCallback onChooseFromGallery;
  final VoidCallback onWriteYourself;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camera = notice.source == ImageSource.camera;
    return MediaPermissionNoticeCard(
      source: notice.source,
      outcome: notice.outcome,
      deniedMessage: camera ? l10n.permCameraDenied : l10n.permPhotosDenied,
      onAskAgain: onAskAgain,
      onOpenSettings: onOpenSettings,
      fallbackLabel: camera
          ? l10n.permFallbackGallery
          : l10n.permFallbackWriteYourself,
      onFallback: camera ? onChooseFromGallery : onWriteYourself,
      fallbackKey: ValueKey(
        camera ? 'permission-fallback-gallery' : 'permission-fallback-write',
      ),
    );
  }
}
