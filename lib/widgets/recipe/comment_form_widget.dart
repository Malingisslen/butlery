// lib/widgets/recipe/comment_form_widget.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Form widget for posting new comments or replies on recipes.
/// Handles both top-level comments and threaded replies with visual feedback.
///
/// BUT-917: persists in-flight draft text per recipe to SharedPreferences
/// so a long thoughtful comment isn't lost to backgrounding / nav-away. Key
/// is `comment_draft_v1_<recipeId>`. Cleared on successful post; survives
/// widget teardown. Per-recipe isolation so two open recipes don't
/// cross-contaminate. When BUT-904 (Reusable AutoSaveManager) lands, this
/// inline pattern should consolidate to that primitive.
class CommentFormWidget extends StatefulWidget {
  final SocialRecipeViewModel socialViewModel;
  final String recipeId;
  final Function(String message, {bool isError}) onShowMessage;
  final VoidCallback? onCommentPosted;

  const CommentFormWidget({
    super.key,
    required this.socialViewModel,
    required this.recipeId,
    required this.onShowMessage,
    this.onCommentPosted,
  });

  @override
  State<CommentFormWidget> createState() => _CommentFormWidgetState();
}

class _CommentFormWidgetState extends State<CommentFormWidget> {
  static const String _draftPrefsPrefix = 'comment_draft_v1_';

  late final TextEditingController _controller;

  // BUT-1049: locally-selected (not-yet-uploaded) image files, capped at
  // RecipeComment.maxImageUrls. Uploaded to Storage only on submit.
  final List<File> _selectedImages = [];
  bool _isUploadingImages = false;

  late final ImagePickerService _imagePicker;
  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _imagePicker = ServiceLocator.get<ImagePickerService>();
    _storageService = ServiceLocator.get<StorageService>();
    _loadDraft();
  }

  bool get _atImageCap => _selectedImages.length >= RecipeComment.maxImageUrls;

  String get _draftKey => '$_draftPrefsPrefix${widget.recipeId}';

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_draftKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        _controller.text = saved;
        // Sync VM state so the send button activates immediately.
        widget.socialViewModel.updateNewCommentText(saved);
      }
    } catch (e) {
      AppLogger.warning('CommentFormWidget: failed to load draft ($e)');
    }
  }

  Future<void> _saveDraft(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (text.isEmpty) {
        await prefs.remove(_draftKey);
      } else {
        await prefs.setString(_draftKey, text);
      }
    } catch (e) {
      // Non-critical — draft persistence is best-effort.
      AppLogger.warning('CommentFormWidget: failed to save draft ($e)');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      AppLogger.warning('CommentFormWidget: failed to clear draft ($e)');
    }
  }

  void _onChanged(String text) {
    widget.socialViewModel.updateNewCommentText(text);
    // Eager save — comments are short, write volume is low; no debounce
    // needed. SharedPreferences writes are async + isolate-fenced so this
    // doesn't block the keystroke.
    _saveDraft(text);
  }

  Future<void> _pickImages() async {
    if (_atImageCap) return;
    final remaining = RecipeComment.maxImageUrls - _selectedImages.length;
    final picked = await _imagePicker.pickMultipleImages(maxImages: remaining);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _selectedImages.addAll(picked.take(remaining));
    });
  }

  void _removeImageAt(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  /// Uploads the selected images to the contract path. Returns the download
  /// URLs, or null if ANY upload failed — the caller must then NOT post the
  /// comment (we never publish a comment referencing images that didn't land).
  Future<List<String>?> _uploadSelectedImages() async {
    final urls = <String>[];
    for (final file in _selectedImages) {
      final url = await _storageService.uploadCommentImage(file);
      if (url == null) return null;
      urls.add(url);
    }
    return urls;
  }

  Future<void> _onSendPressed() async {
    List<String> imageUrls = const [];

    if (_selectedImages.isNotEmpty) {
      setState(() => _isUploadingImages = true);
      try {
        final uploaded = await _uploadSelectedImages();
        if (uploaded == null) {
          if (mounted) {
            widget.onShowMessage(context.l10n.commentImageUploadError,
                isError: true);
          }
          return;
        }
        imageUrls = uploaded;
      } catch (e) {
        AppLogger.error('CommentFormWidget: image upload failed ($e)');
        if (mounted) {
          widget.onShowMessage(context.l10n.commentImageUploadError,
              isError: true);
        }
        return;
      } finally {
        if (mounted) setState(() => _isUploadingImages = false);
      }
    }

    try {
      await widget.socialViewModel
          .postComment(widget.recipeId, imageUrls: imageUrls);
      // Post-success: VM cleared its newCommentText; mirror that on the
      // controller + drop the persisted draft + clear selected images.
      _controller.clear();
      await _clearDraft();
      if (mounted) {
        setState(() => _selectedImages.clear());
        widget.onShowMessage(context.l10n.commentPosted);
      }
      widget.onCommentPosted?.call();
    } catch (e) {
      if (mounted) {
        widget.onShowMessage(context.l10n.commentCouldNotPost, isError: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socialViewModel = widget.socialViewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (socialViewModel.isReplying) ...[
          Container(
            padding: AppDimensions.paddingAll3,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.reply,
                  size: AppDimensions.iconSizeM,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    context.l10n.commentReplyingTo,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: socialViewModel.cancelReply,
                  icon: const Icon(
                    Icons.close,
                    size: AppDimensions.iconSizeM,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SocialAvatarComponents.avatar(
              user: socialViewModel.currentUser,
              displayName: context.l10n.commentYou,
              size: ImageSize.small,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: socialViewModel.isReplying
                      ? context.l10n.commentWriteReply
                      : context.l10n.commentWriteComment,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusM),
                  ),
                  contentPadding: AppDimensions.paddingAll3,
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            if (!_atImageCap)
              IconButton(
                tooltip: context.l10n.commentAttachImage,
                onPressed: _isBusy ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            IconButton(
              onPressed: _canSend ? _onSendPressed : null,
              icon: _isBusy
                  ? const LoadingIndicator(
                      size: AppDimensions.iconSizeS,
                      strokeWidth: 2,
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor:
                    _canSend ? Theme.of(context).colorScheme.primary : null,
                foregroundColor:
                    _canSend ? Theme.of(context).colorScheme.onPrimary : null,
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingS),
          _buildImagePreviewRow(context),
        ],
      ],
    );
  }

  bool get _isBusy =>
      _isUploadingImages || widget.socialViewModel.isPostingComment;

  bool get _canSend =>
      widget.socialViewModel.newCommentText.trim().isNotEmpty && !_isBusy;

  Widget _buildImagePreviewRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.file(
                  _selectedImages[index],
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Semantics(
                  label: context.l10n.a11yCommentRemoveSelectedImage,
                  button: true,
                  child: InkWell(
                    onTap: _isBusy ? null : () => _removeImageAt(index),
                    child: ColoredBox(
                      color: cs.scrim.withValues(alpha: 0.6),
                      child: Icon(
                        Icons.close,
                        size: AppDimensions.iconSizeS,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
