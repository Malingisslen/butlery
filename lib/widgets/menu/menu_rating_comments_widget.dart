// lib/widgets/menu/menu_rating_comments_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Menu Rating and Comments Widget
/// 
/// Displays rating stars, comments, and allows users to rate and comment on menus
class MenuRatingCommentsWidget extends StatefulWidget with StreamManagementMixin {
  final String menuId;
  final double averageRating;
  final int ratingsCount;
  final List<Map<String, dynamic>> ratings;
  final Stream<List<Map<String, dynamic>>> commentsStream;
  final Function(double rating, String? comment) onRate;
  final Function(String comment, String? replyToCommentId) onComment;
  final Function(String commentId) onToggleCommentLike;
  final double? userRating;
  final bool canRate;
  final bool canComment;

  const MenuRatingCommentsWidget({
    super.key,
    required this.menuId,
    required this.averageRating,
    required this.ratingsCount,
    required this.ratings,
    required this.commentsStream,
    required this.onRate,
    required this.onComment,
    required this.onToggleCommentLike,
    this.userRating,
    this.canRate = true,
    this.canComment = true,
  });

  @override
  State<MenuRatingCommentsWidget> createState() => _MenuRatingCommentsWidgetState();
}

class _MenuRatingCommentsWidgetState extends State<MenuRatingCommentsWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _commentController = TextEditingController();
  final _ratingCommentController = TextEditingController();
  double _selectedRating = 0.0;
  String? _replyToCommentId;
  String? _replyToDisplayName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedRating = widget.userRating ?? 0.0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _ratingCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRatingOverview(),
        const SizedBox(height: AppDimensions.spacingM),
        _buildTabBar(),
        _buildTabContent(),
      ],
    );
  }

  Widget _buildRatingOverview() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Average rating display
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.averageRating.toStringAsFixed(1),
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    _buildStarRating(widget.averageRating, size: 20),
                    const SizedBox(width: AppDimensions.spacingS),
                    Text(
                      '(${widget.ratingsCount})',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingS),
                _buildRatingDistribution(),
              ],
            ),
          ),
          
          // Rate button
          if (widget.canRate)
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openRatingDialog(),
                  icon: Icon(
                    widget.userRating != null ? Icons.edit : Icons.star,
                    size: 18,
                  ),
                  label: Text(
                    widget.userRating != null ? 'Ändra' : 'Betygsätt',
                    style: AppTextStyles.bodySmall,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.onWarning,
                    minimumSize: const Size(100, 36),
                  ),
                ),
                if (widget.userRating != null) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    'Ditt: ${widget.userRating!.toStringAsFixed(1)}⭐',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    // Calculate rating distribution
    final distribution = <int, int>{};
    for (int i = 1; i <= 5; i++) {
      distribution[i] = 0;
    }
    
    for (final rating in widget.ratings) {
      final ratingValue = (rating['rating'] as double).round();
      distribution[ratingValue] = (distribution[ratingValue] ?? 0) + 1;
    }

    return Column(
      children: [
        for (int stars = 5; stars >= 1; stars--)
          _buildRatingBar(stars, distribution[stars] ?? 0, widget.ratingsCount),
      ],
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            '$stars',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.star,
            size: 12,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingS),
          SizedBox(
            width: 20,
            child: Text(
              count.toString(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, size: 18),
                SizedBox(width: AppDimensions.spacingS),
                Text('Betyg'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment, size: 18),
                SizedBox(width: AppDimensions.spacingS),
                Text('Kommentarer'),
              ],
            ),
          ),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.onSurface.withValues(alpha: 0.6),
        indicator: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 400,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildRatingsTab(),
          _buildCommentsTab(),
        ],
      ),
    );
  }

  Widget _buildRatingsTab() {
    if (widget.ratings.isEmpty) {
      return _buildEmptyRatings();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      itemCount: widget.ratings.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final rating = widget.ratings[index];
        return _buildRatingCard(rating);
      },
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> rating) {
    final ratingValue = rating['rating'] as double;
    final comment = rating['comment'] as String?;
    final ratedByDisplayName = rating['ratedByDisplayName'] as String? ?? 'Anonym';
    final ratedAt = rating['ratedAt'] as DateTime?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                ratedByDisplayName.isNotEmpty ? ratedByDisplayName[0].toUpperCase() : '?',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ratedByDisplayName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      _buildStarRating(ratingValue, size: 16),
                      const SizedBox(width: AppDimensions.spacingS),
                      if (ratedAt != null)
                        Text(
                          _formatDate(ratedAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingS),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Text(
              comment,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        if (widget.canComment) _buildCommentInput(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.commentsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return _buildEmptyComments();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppDimensions.spacingM),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingM),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return _buildCommentCard(comment);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_replyToDisplayName != null) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingS),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    'Svarar till $_replyToDisplayName',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (mounted) setState(() {
                        _replyToCommentId = null;
                        _replyToDisplayName = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingS),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _replyToDisplayName != null ? 'Skriv ditt svar...' : 'Skriv en kommentar...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingM,
                      vertical: AppDimensions.spacingS,
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              IconButton(
                onPressed: _submitComment,
                icon: const Icon(
                  Icons.send,
                  color: AppColors.primary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final commentText = comment['comment'] as String? ?? '';
    final commentedByDisplayName = comment['commentedByDisplayName'] as String? ?? 'Anonym';
    final commentedAt = comment['commentedAt'] as DateTime?;
    final likes = comment['likes'] as int? ?? 0;
    final replyToCommentId = comment['replyToCommentId'] as String?;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: replyToCommentId != null ? AppColors.surfaceVariant.withValues(alpha: 0.5) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  commentedByDisplayName.isNotEmpty ? commentedByDisplayName[0].toUpperCase() : '?',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commentedByDisplayName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (commentedAt != null)
                      Text(
                        _formatDate(commentedAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            commentText,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Row(
            children: [
              GestureDetector(
                onTap: () => widget.onToggleCommentLike(comment['id']),
                child: Row(
                  children: [
                    Icon(
                      likes > 0 ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: likes > 0 ? AppColors.error : AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                    if (likes > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        likes.toString(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),
              GestureDetector(
                onTap: () {
                  if (mounted) setState(() {
                    _replyToCommentId = comment['id'];
                    _replyToDisplayName = commentedByDisplayName;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.reply,
                      size: 16,
                      color: AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Svara',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRatings() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.star_border,
            size: 48,
            color: AppColors.outline,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            'Inga betyg än',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            'Bli den första att betygsätta denna meny!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyComments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: AppColors.outline,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            'Inga kommentarer än',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            'Starta diskussionen om denna meny!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starRating = index + 1;
        final isFullStar = rating >= starRating;
        final isHalfStar = rating >= starRating - 0.5 && rating < starRating;

        return Icon(
          isFullStar ? Icons.star : (isHalfStar ? Icons.star_half : Icons.star_border),
          size: size,
          color: AppColors.warning,
        );
      }),
    );
  }

  void _openRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.userRating != null ? 'Ändra betyg' : 'Betygsätt meny',
          style: AppTextStyles.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vad tycker du om denna meny?',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starRating = index + 1;
                return GestureDetector(
                  onTap: () {
                    if (mounted) setState(() {
                      _selectedRating = starRating.toDouble();
                    });
                  },
                  child: Icon(
                    _selectedRating >= starRating ? Icons.star : Icons.star_border,
                    size: 32,
                    color: AppColors.warning,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextField(
              controller: _ratingCommentController,
              decoration: const InputDecoration(
                labelText: 'Kommentar (valfritt)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: _selectedRating > 0 ? () {
              Navigator.of(context).pop();
              widget.onRate(_selectedRating, _ratingCommentController.text.isEmpty ? null : _ratingCommentController.text);
              _ratingCommentController.clear();
            } : null,
            child: const Text('Betygsätt'),
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    final comment = _commentController.text.trim();
    if (comment.isNotEmpty) {
      widget.onComment(comment, _replyToCommentId);
      _commentController.clear();
      if (mounted) setState(() {
        _replyToCommentId = null;
        _replyToDisplayName = null;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d sedan';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h sedan';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m sedan';
    } else {
      return 'Nu';
    }
  }
}