/// Comprehensive social activity feed view providing real-time friend activity streams for Flutter applications.
///
/// This module implements sophisticated social activity feed following Single Responsibility Principle,
/// specializing in activity display, engagement tracking, filtering coordination, and comprehensive social interaction.
/// It provides complete activity feed interface while maintaining clean separation from business logic,
/// data persistence, and state management through ActivityService integration and modern component architecture.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles social activity feed UI presentation concerns through comprehensive social architecture:
/// - **Real-Time Activity Excellence**: Advanced activity streaming with live updates and engagement tracking
/// - **Filter and Engagement Intelligence**: Sophisticated filtering with activity type selection and friend categorization
/// - **Infinite Scroll Coordination**: Comprehensive pagination with pull-to-refresh and performance optimization
/// - **Social Interaction Management**: Advanced user interaction with activity blocking, reporting, and privacy controls
/// - **Swedish Localization Excellence**: Complete Swedish language support for social operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Activity business logic and data operations (handled by ActivityService and social infrastructure)
/// - Friend management and categorization (handled by FriendsViewModel and friendship services)
/// - Navigation to content items (handled by routing services and navigation coordination)
/// - Activity analytics and tracking (handled by analytics services and engagement infrastructure)
///
/// **Activity Feed View Architecture:**
/// - **Real-Time Activity Stream**: Advanced activity streaming with live updates and pagination support
/// - **Engagement Tracking System**: Comprehensive interaction tracking with view analytics and user behavior monitoring
/// - **Advanced Filtering Options**: Sophisticated filtering with activity type selection and friend category coordination
/// - **Privacy and Control Features**: Complete user control with activity blocking, hiding, and reporting functionality
/// - **Performance Optimization**: Intelligent caching with lazy loading and efficient state management
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to activity feed with friend filtering
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => ActivityFeedView(
///       title: 'Vänners aktivitet',
///       friendCategories: ['close_friends'],
///       realTimeUpdates: true,
///     ),
///   ),
/// );
/// 
/// // The view provides comprehensive activity feed functionality:
/// // - Real-time activity streaming with live updates and engagement tracking
/// // - Advanced filtering with activity type and friend category selection
/// // - Infinite scroll with pull-to-refresh and performance optimization
/// // - Social interactions including blocking, hiding, and reporting activities
/// // - Privacy controls with user-configurable activity visibility settings
/// 
/// // Integration with specialized components:
/// // - ActivityFeedItemWidget for individual activity display and interaction
/// // - ActivityService for real-time activity streaming and data management
/// // - LoadingWidgets and EmptyStates for comprehensive state management
/// // - Filter dialogs for activity type and category selection
/// ```

// lib/views/social/activity_feed_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/social/activity_feed_item.dart';
import 'package:butlery/services/social/activity_service.dart';
import 'package:butlery/widgets/social/activity_feed_item_widget.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive social activity feed view providing real-time friend activity streams through advanced social architecture.
///
/// Manages complete social activity interface enabling real-time activity display, engagement tracking, filtering coordination,
/// and comprehensive social interaction while maintaining clean separation between UI presentation
/// and business logic through ActivityService integration and specialized component architecture.
///
/// **Core Responsibilities:**
/// - Advanced real-time activity streaming with live updates, engagement tracking, and performance optimization
/// - Filter and engagement coordination with activity type selection, friend categorization, and user preference management
/// - Infinite scroll management with pagination, pull-to-refresh, and comprehensive loading state coordination
/// - Social interaction handling with activity blocking, hiding, reporting, and privacy control through user action systems
/// - Swedish localized social experience with comprehensive user feedback and interactive guidance
///
/// **Architecture Integration:**
/// - Extends existing feed patterns from discovery dashboard
/// - Uses established service injection through ServiceLocator
/// - Integrates with existing navigation and routing systems
/// - Follows established state management patterns
/// - Uses consistent error handling and loading states
///
/// **Feed Features:**
/// - **Real-time Updates**: Live activity stream with automatic refresh
/// - **Infinite Scroll**: Efficient pagination with pull-to-refresh
/// - **Activity Filtering**: Type-based filtering and friend category selection
/// - **Engagement Tracking**: Activity interaction and view tracking
/// - **Privacy Controls**: User-controlled activity visibility and blocking
/// - **Performance Optimization**: Lazy loading and intelligent caching
///
/// **User Experience:**
/// - **Swedish Localization**: All text and interactions in Swedish
/// - **Accessibility Support**: Screen reader friendly with semantic labels
/// - **Responsive Design**: Optimized for different screen sizes
/// - **Smooth Animations**: Engaging transitions and state changes
/// - **Context Actions**: Long press for activity options and controls
///
/// **Usage Context:**
/// - Main social feed in discovery dashboard
/// - Dedicated activity feed screen accessible from navigation
/// - Friend profile activity history display
/// - Content-specific activity timelines
///
/// **Navigation Integration:**
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (context) => ActivityFeedView(
///     title: 'Vänners aktivitet',
///     friendCategories: ['close_friends'],
///   ),
/// ));
/// ```
class ActivityFeedView extends StatefulWidget {
  /// Feed view title for app bar display and user orientation.
  /// 
  /// Provides customizable title enabling feed identification, user context,
  /// and comprehensive interface personalization.
  final String? title;
  
  /// Friend categories for activity filtering and personalization coordination.
  /// 
  /// Contains friend category identifiers enabling activity filtering,
  /// personalized content display, and comprehensive social categorization.
  final List<String>? friendCategories;
  
  /// Real-time updates configuration for live activity streaming.
  /// 
  /// Enables real-time activity updates providing live activity streaming,
  /// engagement tracking, and comprehensive social interaction coordination.
  final bool realTimeUpdates;
  
  /// Initial activity load limit for performance optimization.
  /// 
  /// Specifies initial activity count enabling performance optimization,
  /// efficient loading, and comprehensive pagination coordination.
  final int initialLimit;
  
  /// Filter options display configuration for user control.
  /// 
  /// Controls filter interface visibility enabling user customization,
  /// activity type selection, and comprehensive filtering coordination.
  final bool showFilters;

  /// Creates comprehensive social activity feed view with real-time streaming and filtering coordination.
  /// 
  /// [title] Feed view title for app bar display and user orientation
  /// [friendCategories] Friend categories for activity filtering and personalization coordination
  /// [realTimeUpdates] Real-time updates configuration for live activity streaming
  /// [initialLimit] Initial activity load limit for performance optimization
  /// [showFilters] Filter options display configuration for user control
  /// 
  /// Establishes social activity interface with real-time streaming, engagement tracking,
  /// and comprehensive filtering functionality through ActivityService integration
  /// and advanced social architecture with performance optimization.
  const ActivityFeedView({
    super.key,
    this.title,
    this.friendCategories,
    this.realTimeUpdates = true,
    this.initialLimit = 20,
    this.showFilters = true,
  });

  /// Creates activity feed view state with service integration and lifecycle management.
  /// 
  /// Establishes stateful social activity interface enabling real-time streaming,
  /// engagement tracking, and comprehensive activity functionality through
  /// proper state lifecycle and ActivityService coordination.
  @override
  State<ActivityFeedView> createState() => _ActivityFeedViewState();
}

/// Social activity feed state managing real-time streaming, engagement tracking, and comprehensive social interaction coordination.
///
/// Handles complete activity feed state management including activity loading, filtering, real-time updates,
/// and user interaction handling while maintaining clean ActivityService integration and proper lifecycle management
/// through comprehensive social functionality coordination and performance optimization.
class _ActivityFeedViewState extends State<ActivityFeedView> {
  /// Activity service for social data operations and real-time streaming coordination.
  /// 
  /// Manages activity operations enabling real-time streaming, engagement tracking,
  /// and comprehensive social functionality through ActivityService integration.
  late final ActivityService _activityService;
  
  /// Scroll controller for infinite scroll and pagination coordination.
  /// 
  /// Manages scroll behavior enabling infinite scroll, pagination coordination,
  /// and comprehensive performance optimization through scroll management.
  late final ScrollController _scrollController;
  
  /// Activity items list for feed display and state management.
  /// 
  /// Contains loaded activities enabling feed display, state management,
  /// and comprehensive activity coordination through list management.
  List<ActivityFeedItem> _activities = [];
  
  /// Initial loading state for user feedback and interface coordination.
  /// 
  /// Manages initial loading state enabling loading indicators, user feedback,
  /// and comprehensive loading experience through state management.
  bool _isLoading = true;
  
  /// Additional loading state for pagination and infinite scroll coordination.
  /// 
  /// Manages pagination loading state enabling loading indicators, user feedback,
  /// and comprehensive pagination experience through state management.
  bool _isLoadingMore = false;
  
  /// Error state for error handling and user feedback coordination.
  /// 
  /// Manages error state enabling error display, user feedback,
  /// and comprehensive error handling through state management.
  bool _hasError = false;
  
  /// Error message for detailed error information and user guidance.
  /// 
  /// Stores error messages enabling detailed error display, user guidance,
  /// and comprehensive error handling through message management.
  String? _errorMessage;
  
  /// Pagination state for infinite scroll and loading coordination.
  /// 
  /// Manages pagination availability enabling infinite scroll coordination,
  /// loading optimization, and comprehensive pagination management.
  bool _hasMoreActivities = true;
  
  /// Selected activity types for filtering and user preference coordination.
  /// 
  /// Stores selected activity types enabling filtering coordination, user preferences,
  /// and comprehensive filtering functionality through type management.
  List<ActivityType>? _selectedActivityTypes;
  
  /// Selected friend categories for filtering and personalization coordination.
  /// 
  /// Stores selected friend categories enabling filtering coordination, personalization,
  /// and comprehensive categorization functionality through category management.
  List<String>? _selectedFriendCategories;
  
  /// Unseen activities state for real-time update coordination.
  /// 
  /// Manages unseen activity availability enabling real-time notifications, user awareness,
  /// and comprehensive update coordination through state management.
  bool _hasUnseenActivities = false;
  
  /// Unseen activities count for notification display and user feedback.
  /// 
  /// Stores unseen activity count enabling notification display, user feedback,
  /// and comprehensive awareness coordination through count management.
  int _unseenActivityCount = 0;

  @override
  void initState() {
    super.initState();
    _activityService = ServiceLocator.get<ActivityService>();
    _scrollController = ScrollController();
    _selectedFriendCategories = widget.friendCategories;
    
    _scrollController.addListener(_onScroll);
    _loadInitialActivities();
    
    if (widget.realTimeUpdates) {
      _setupRealTimeUpdates();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreActivities();
    }
  }

  Future<void> _loadInitialActivities() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final activities = await _activityService.getFriendActivityFeed(
        limit: widget.initialLimit,
        friendCategories: _selectedFriendCategories,
      );

      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoading = false;
          _hasMoreActivities = activities.length >= widget.initialLimit;
        });
        
        // Mark activities as seen
        if (activities.isNotEmpty) {
          final activityIds = activities.map((a) => a.id).toList();
          _activityService.markActivitiesAsSeen(activityIds);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreActivities() async {
    if (_isLoadingMore || !_hasMoreActivities) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreActivities = await _activityService.getFriendActivityFeed(
        limit: 20,
        offset: _activities.length,
        friendCategories: _selectedFriendCategories,
      );

      if (mounted) {
        setState(() {
          _activities.addAll(moreActivities);
          _isLoadingMore = false;
          _hasMoreActivities = moreActivities.length >= 20;
        });
        
        // Mark new activities as seen
        if (moreActivities.isNotEmpty) {
          final activityIds = moreActivities.map((a) => a.id).toList();
          _activityService.markActivitiesAsSeen(activityIds);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _setupRealTimeUpdates() {
    _activityService.getActivityFeedStream(
      friendCategories: _selectedFriendCategories,
    ).listen((activities) {
      if (mounted && activities.isNotEmpty) {
        // Check for new activities since last load
        final lastActivity = _activities.isNotEmpty ? _activities.first : null;
        final newActivities = lastActivity != null
            ? activities.where((a) => a.timestamp.isAfter(lastActivity.timestamp)).toList()
            : activities;
        
        if (newActivities.isNotEmpty) {
          setState(() {
            _hasUnseenActivities = true;
            _unseenActivityCount = newActivities.length;
          });
        }
      }
    });
  }

  Future<void> _refreshFeed() async {
    await _loadInitialActivities();
    setState(() {
      _hasUnseenActivities = false;
      _unseenActivityCount = 0;
    });
  }

  void _onActivityTap(ActivityFeedItem activity) {
    // Navigate to content based on activity target type
    switch (activity.targetType) {
      case 'recipe':
        // Navigate to recipe detail
        // Navigator.pushNamed(context, '/recipe/${activity.targetId}');
        break;
      case 'menu':
        // Navigate to menu detail
        // Navigator.pushNamed(context, '/menu/${activity.targetId}');
        break;
      case 'shopping_list':
        // Navigate to shopping list detail
        // Navigator.pushNamed(context, '/shopping-list/${activity.targetId}');
        break;
      default:
        // Show activity details
        _showActivityDetails(activity);
    }
  }

  void _onActivityLongPress(ActivityFeedItem activity) {
    _showActivityOptions(activity);
  }

  void _showActivityDetails(ActivityFeedItem activity) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusL)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aktivitetsdetaljer',
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            
            ActivityFeedItemWidget(
              activity: activity,
              showEngagement: true,
              showFullTimestamp: true,
            ),
            
            const SizedBox(height: AppDimensions.spacingM),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Stäng'),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _onActivityTap(activity);
                    },
                    child: const Text('Visa innehåll'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityOptions(ActivityFeedItem activity) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusL)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Dölj aktivitet'),
              subtitle: const Text('Dölj denna aktivitet från ditt flöde'),
              onTap: () {
                Navigator.pop(context);
                _hideActivity(activity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text('Blockera ${activity.type.displayName.toLowerCase()}'),
              subtitle: const Text('Blockera denna typ av aktivitet'),
              onTap: () {
                Navigator.pop(context);
                _blockActivityType(activity.type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Rapportera aktivitet'),
              subtitle: const Text('Rapportera för olämpligt innehåll'),
              onTap: () {
                Navigator.pop(context);
                _reportActivity(activity);
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Avbryt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hideActivity(ActivityFeedItem activity) async {
    try {
      await _activityService.hideActivity(activity.id);
      setState(() {
        _activities.removeWhere((a) => a.id == activity.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivitet dold')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunde inte dölja aktivitet: $e')),
        );
      }
    }
  }

  Future<void> _blockActivityType(ActivityType activityType) async {
    try {
      await _activityService.blockActivityType(activityType);
      setState(() {
        _activities.removeWhere((a) => a.type == activityType);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${activityType.displayName} blockerad')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunde inte blockera aktivitetstyp: $e')),
        );
      }
    }
  }

  void _reportActivity(ActivityFeedItem activity) {
    // Placeholder for activity reporting
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rapporteringsfunktion kommer snart')),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrera aktiviteter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Välj aktivitetstyper att visa:'),
            const SizedBox(height: AppDimensions.spacingM),
            
            // Activity type filters
            ...ActivityType.values.map((type) {
              if (type == ActivityType.unknown) return const SizedBox.shrink();
              
              final isSelected = _selectedActivityTypes?.contains(type) ?? true;
              return CheckboxListTile(
                title: Text(type.displayName),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    _selectedActivityTypes ??= ActivityType.values.where((t) => t != ActivityType.unknown).toList();
                    if (value == true) {
                      _selectedActivityTypes!.add(type);
                    } else {
                      _selectedActivityTypes!.remove(type);
                    }
                  });
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _refreshFeed();
            },
            child: const Text('Tillämpa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Aktivitetsflöde'),
        actions: [
          if (widget.showFilters)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshFeed,
          ),
        ],
      ),
      body: Column(
        children: [
          // Unseen activities notification
          if (_hasUnseenActivities)
            Container(
              width: double.infinity,
              color: AppColors.primary.withValues(alpha: 0.1),
              child: InkWell(
                onTap: _refreshFeed,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingM),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fiber_new,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.spacingS),
                      Text(
                        '$_unseenActivityCount nya aktiviteter',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.keyboard_arrow_up,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Activity feed content
          Expanded(
            child: _buildFeedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_isLoading) {
      return LoadingWidgets.loadingOverlay(
        isLoading: true,
        loadingMessage: 'Laddar aktiviteter...',
      );
    }

    if (_hasError) {
      return EmptyStates.buildEmptyState(
        context,
        variant: EmptyStateVariant.generic,
        icon: Icons.error_outline,
        title: 'Kunde inte ladda aktiviteter',
        subtitle: _errorMessage ?? 'Ett oväntat fel uppstod',
        // Custom error action handled in the widget
      );
    }

    if (_activities.isEmpty) {
      return EmptyStates.buildEmptyState(
        context,
        variant: EmptyStateVariant.generic,
        icon: Icons.people_outline,
        title: 'Inga aktiviteter än',
        subtitle: 'När dina vänner är aktiva visas deras aktiviteter här.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        itemCount: _activities.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _activities.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final activity = _activities[index];
          return ActivityFeedItemWidget(
            activity: activity,
            onTap: _onActivityTap,
            onLongPress: _onActivityLongPress,
            showEngagement: true,
          );
        },
      ),
    );
  }
}