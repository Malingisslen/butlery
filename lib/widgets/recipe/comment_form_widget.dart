// lib/widgets/recipe/comment_form_widget.dart

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/models/media_permission_notice.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/permissions/media_permission_notice_card.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/voice/voice_prompt_button.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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

  /// Injectable per OsPermissionHelper's contract — tests stub mic
  /// permission statuses without touching plugin channels.
  final PermissionGateway voicePermissionGateway;

  const CommentFormWidget({
    super.key,
    required this.socialViewModel,
    required this.recipeId,
    required this.onShowMessage,
    this.onCommentPosted,
    this.voicePermissionGateway = const DefaultPermissionGateway(),
  });

  @override
  State<CommentFormWidget> createState() => _CommentFormWidgetState();
}

class _CommentFormWidgetState extends State<CommentFormWidget> {
  late final TextEditingController _controller;
  late final AutoSaveManager<String> _draftManager;

  // BUT-1049: locally-selected (not-yet-uploaded) image files, capped at
  // RecipeComment.maxImageUrls. Uploaded to Storage only on submit.
  final List<File> _selectedImages = [];
  bool _isUploadingImages = false;

  // Flow 07: what the last pick's photo-library answer leaves to explain.
  MediaPermissionNotice? _permissionNotice;

  late final ImagePickerService _imagePicker;
  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _imagePicker = ServiceLocator.get<ImagePickerService>();
    _storageService = ServiceLocator.get<StorageService>();
    // BUT-917 per-recipe isolation: the key carries the recipe id so two open
    // recipes don't cross-contaminate. BUT-904: persistence is now the shared
    // AutoSaveManager; this widget keeps only the load-and-apply glue.
    _draftManager = AutoSaveManager<String>(
      storageKey: 'comment_draft_v1_${widget.recipeId}',
      encode: (text) => text,
      decode: (raw) => raw,
      logLabel: 'CommentFormWidget',
    );
    _restoreDraft();
  }

  bool get _atImageCap => _selectedImages.length >= RecipeComment.maxImageUrls;

  Future<void> _restoreDraft() async {
    final saved = await _draftManager.load();
    if (saved != null && saved.isNotEmpty && mounted) {
      _controller.text = saved;
      // Sync VM state so the send button activates immediately.
      widget.socialViewModel.updateNewCommentText(saved);
    }
  }

  void _onChanged(String text) {
    widget.socialViewModel.updateNewCommentText(text);
    // Eager save — comments are short, write volume is low; no debounce
    // needed. SharedPreferences writes are async + isolate-fenced so this
    // doesn't block the keystroke.
    _draftManager.save(text);
  }

  /// [askAgain] is "Fråga igen" on the notice: the user asked for the
  /// system prompt, so our explanation is not repeated
  /// (produktregler.md:683).
  Future<void> _pickImages({bool askAgain = false}) async {
    // The notice's Fråga igen stays tappable while a post uploads the list.
    if (_atImageCap || _isBusy) return;
    final remaining = RecipeComment.maxImageUrls - _selectedImages.length;
    // Flow 07: explanation before the system prompt (produktregler.md:682).
    final outcome = await _imagePicker.pickMultipleImagesWithOutcome(
      maxImages: remaining,
      rationale: askAgain ? null : mediaRationalePrompt(context),
    );
    if (!mounted) return;
    setState(() {
      _permissionNotice = MediaPermissionNotice.after(
        ImageSource.gallery,
        outcome.permission,
      );
      _selectedImages.addAll(outcome.files.take(remaining));
    });
  }

  void _removeImageAt(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  /// A dictated comment lands EDITABLE in the field, appended to whatever
  /// was already typed (typed text is never mutated — a separator space is
  /// added only when one is missing), and flows through _onChanged — so
  /// the send-button state, the draft persistence, and (on post) the
  /// profanity + account-maturity gates all see it exactly as if it had
  /// been typed.
  void _onVoiceTranscript(String transcript) {
    final existing = _controller.text;
    final needsSeparator =
        existing.isNotEmpty &&
        !existing.endsWith(' ') &&
        !existing.endsWith('\n');
    final combined = existing.isEmpty
        ? transcript
        : '$existing${needsSeparator ? ' ' : ''}$transcript';
    _controller.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
    _onChanged(combined);
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
            widget.onShowMessage(
              context.l10n.commentImageUploadError,
              isError: true,
            );
          }
          return;
        }
        imageUrls = uploaded;
      } catch (e) {
        AppLogger.error('CommentFormWidget: image upload failed ($e)');
        if (mounted) {
          widget.onShowMessage(
            context.l10n.commentImageUploadError,
            isError: true,
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isUploadingImages = false);
      }
    }

    // Snapshot what is being SENT: text arriving while the post is in
    // flight (a dictation finishing, more typing) must survive the
    // success cleanup — clearing blindly would silently discard it.
    final sentText = _controller.text;
    try {
      await widget.socialViewModel.postComment(
        widget.recipeId,
        imageUrls: imageUrls,
      );
      // Post-success: remove exactly what was sent; keep anything that
      // landed in the field during the post.
      final current = _controller.text;
      if (current == sentText) {
        _controller.clear();
        await _draftManager.clear();
      } else {
        final remainder = current.startsWith(sentText)
            ? current.substring(sentText.length).trimLeft()
            : current;
        _controller.value = TextEditingValue(
          text: remainder,
          selection: TextSelection.collapsed(offset: remainder.length),
        );
        _onChanged(remainder);
      }
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
    _draftManager.dispose();
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
            padding: AppDimensions.paddingAll4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            ),
            child: Row(
              children: [
                ButleryIcon(
                  ButleryIcons.reply,
                  size: AppDimensions.iconSizeM,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: AppDimensions.space4),
                Expanded(
                  child: Text(
                    context.l10n.commentReplyingTo,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: socialViewModel.cancelReply,
                  icon: const ButleryIcon(
                    ButleryIcons.x,
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
            const SizedBox(width: AppDimensions.space4),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: socialViewModel.isReplying
                      ? context.l10n.commentWriteReply
                      : context.l10n.commentWriteComment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
                  ),
                  contentPadding: AppDimensions.paddingAll4,
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: AppDimensions.space4),
            VoicePromptButton(
              onTranscript: _onVoiceTranscript,
              enabled: !_isBusy,
              permissionGateway: widget.voicePermissionGateway,
              startTooltip: context.l10n.voiceCommentStart,
              rationaleTitle: context.l10n.voiceCommentMicRationaleTitle,
              rationaleBody: context.l10n.voiceMicRationaleBody,
            ),
            if (!_atImageCap)
              IconButton(
                tooltip: context.l10n.commentAttachImage,
                onPressed: _isBusy ? null : _pickImages,
                icon: const ButleryIcon(ButleryIcons.camera),
              ),
            IconButton(
              tooltip: context.l10n.commonSend,
              onPressed: _canSend ? _onSendPressed : null,
              // Busy: the plate line in the button's place, never a
              // spinner (Grafisk manual v6:209).
              icon: _isBusy
                  ? SizedBox(
                      width: AppDimensions.iconSizeM,
                      child: PlateLine(
                        semanticLabel: context.l10n.sendingComment,
                      ),
                    )
                  : const ButleryIcon(ButleryIcons.send),
              style: IconButton.styleFrom(
                backgroundColor: _canSend
                    ? Theme.of(context).colorScheme.primary
                    : null,
                foregroundColor: _canSend
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
          ],
        ),
        if (_permissionNotice case final notice?) ...[
          const SizedBox(height: AppDimensions.space4),
          // The library is the only source here, and writing it yourself
          // is offered in photo import (Malin, decision A, 2026-10-07).
          MediaPermissionNoticeCard(
            source: notice.source,
            outcome: notice.outcome,
            deniedMessage: context.l10n.permPhotosDeniedImage,
            onAskAgain: () => _pickImages(askAgain: true),
            onOpenSettings: OsPermissionHelper.openSettings,
          ),
        ],
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space4),
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
            const SizedBox(width: AppDimensions.space4),
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
                  child: PressUnchanged(
                    child: InkWell(
                      onTap: _isBusy ? null : () => _removeImageAt(index),
                      child: ColoredBox(
                        color: cs.scrim.withValues(alpha: 0.6),
                        child: ButleryIcon(
                          ButleryIcons.x,
                          size: AppDimensions.iconSizeS,
                          color: cs.onPrimary,
                        ),
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
