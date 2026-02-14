import 'package:flutter/material.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Settings view for notification category toggles and quiet hours.
class NotificationPreferencesView extends StatefulWidget {
  const NotificationPreferencesView({super.key});

  @override
  State<NotificationPreferencesView> createState() =>
      _NotificationPreferencesViewState();
}

class _NotificationPreferencesViewState
    extends State<NotificationPreferencesView> {
  NotificationPreferences _preferences = NotificationPreferences.defaults();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final service = ServiceLocator.get<NotificationService>();
      final prefs = await service.getPreferences();
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferences(NotificationPreferences updated) async {
    setState(() => _preferences = updated);
    try {
      final service = ServiceLocator.get<NotificationService>();
      await service.updatePreferences(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte spara inställningar'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aviseringar')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMasterToggle(),
                      const SizedBox(height: AppDimensions.spacingXl),
                      _buildCategorySection(),
                      const SizedBox(height: AppDimensions.spacingXl),
                      _buildQuietHoursSection(),
                      const SizedBox(height: AppDimensions.spacingXl),
                      _buildSoundVibrationSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMasterToggle() {
    return SwitchListTile(
      title: Text(
        'Aktivera aviseringar',
        style: AppTextStyles.titleMedium,
      ),
      subtitle: Text(
        'Aktivera eller inaktivera alla aviseringar',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
      ),
      secondary: Icon(
        _preferences.enabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        color: AppColors.forestGreen,
        size: AppDimensions.iconSizeL,
      ),
      value: _preferences.enabled,
      onChanged: (value) => _savePreferences(
        _copyPreferences(enabled: value),
      ),
      activeTrackColor:
          AppColors.forestGreen.withValues(alpha: AppDimensions.opacityHalf),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.forestGreen;
        }
        return null;
      }),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aviseringskategorier', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppDimensions.spacingMd),
        ..._categoryItems.map((item) => _buildCategoryTile(item)),
      ],
    );
  }

  Widget _buildCategoryTile(_CategoryItem item) {
    final isEnabled = _preferences.categorySettings[item.category] ?? true;

    return Opacity(
      // Dim category toggles when master toggle is off
      opacity: _preferences.enabled ? 1.0 : AppDimensions.opacityMedium,
      child: SwitchListTile(
        title: Text(item.label, style: AppTextStyles.titleMedium),
        secondary: Icon(
          item.icon,
          color: AppColors.forestGreen,
          size: AppDimensions.iconSizeL,
        ),
        value: isEnabled,
        onChanged: _preferences.enabled
            ? (value) {
                final updatedSettings = Map<NotificationCategory, bool>.from(
                    _preferences.categorySettings);
                updatedSettings[item.category] = value;
                _savePreferences(
                  _copyPreferences(categorySettings: updatedSettings),
                );
              }
            : null,
        activeTrackColor:
            AppColors.forestGreen.withValues(alpha: AppDimensions.opacityHalf),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.forestGreen;
          }
          return null;
        }),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildQuietHoursSection() {
    final hasQuietHours = _preferences.quietHoursStart != null &&
        _preferences.quietHoursEnd != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tysta timmar', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppDimensions.spacingMd),
        SwitchListTile(
          title: Text(
            'Aktivera tysta timmar',
            style: AppTextStyles.titleMedium,
          ),
          subtitle: Text(
            'Inga aviseringar under vald tidsperiod',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
          ),
          secondary: const Icon(
            Icons.do_not_disturb_on_outlined,
            color: AppColors.forestGreen,
            size: AppDimensions.iconSizeL,
          ),
          value: hasQuietHours,
          onChanged: (value) {
            if (value) {
              // Enable with defaults 22:00-08:00
              _savePreferences(
                _copyPreferences(
                  quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
                  quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
                  clearQuietHours: false,
                ),
              );
            } else {
              _savePreferences(
                _copyPreferences(clearQuietHours: true),
              );
            }
          },
          activeTrackColor: AppColors.forestGreen
              .withValues(alpha: AppDimensions.opacityHalf),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.forestGreen;
            }
            return null;
          }),
          contentPadding: EdgeInsets.zero,
        ),
        if (hasQuietHours) ...[
          const SizedBox(height: AppDimensions.spacingMd),
          _buildTimePickerRow(),
        ],
      ],
    );
  }

  Widget _buildTimePickerRow() {
    final start = _preferences.quietHoursStart!;
    final end = _preferences.quietHoursEnd!;
    final startText = _formatTime(start);
    final endText = _formatTime(end);

    return Row(
      children: [
        Expanded(
          child: _buildTimeTile(
            label: 'Från',
            time: startText,
            onTap: () => _pickTime(isStart: true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingSm),
          child: Icon(Icons.arrow_forward, color: AppColors.textMedium),
        ),
        Expanded(
          child: _buildTimeTile(
            label: 'Till',
            time: endText,
            onTap: () => _pickTime(isStart: false),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeTile({
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(
              label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              time,
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? _preferences.quietHoursStart ?? const TimeOfDay(hour: 22, minute: 0)
        : _preferences.quietHoursEnd ?? const TimeOfDay(hour: 8, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null && mounted) {
      if (isStart) {
        _savePreferences(
          _copyPreferences(quietHoursStart: picked),
        );
      } else {
        _savePreferences(
          _copyPreferences(quietHoursEnd: picked),
        );
      }
    }
  }

  Widget _buildSoundVibrationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text('Ljud', style: AppTextStyles.titleMedium),
          secondary: Icon(
            _preferences.soundEnabled
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            color: AppColors.forestGreen,
            size: AppDimensions.iconSizeL,
          ),
          value: _preferences.soundEnabled,
          onChanged: (value) => _savePreferences(
            _copyPreferences(soundEnabled: value),
          ),
          activeTrackColor: AppColors.forestGreen
              .withValues(alpha: AppDimensions.opacityHalf),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.forestGreen;
            }
            return null;
          }),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(),
        SwitchListTile(
          title: Text('Vibration', style: AppTextStyles.titleMedium),
          secondary: const Icon(
            Icons.vibration_outlined,
            color: AppColors.forestGreen,
            size: AppDimensions.iconSizeL,
          ),
          value: _preferences.vibrationEnabled,
          onChanged: (value) => _savePreferences(
            _copyPreferences(vibrationEnabled: value),
          ),
          activeTrackColor: AppColors.forestGreen
              .withValues(alpha: AppDimensions.opacityHalf),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.forestGreen;
            }
            return null;
          }),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /// Manual copyWith since the model doesn't provide one.
  /// Using flags for nullable fields that need explicit clearing.
  NotificationPreferences _copyPreferences({
    bool? enabled,
    Map<NotificationCategory, bool>? categorySettings,
    Map<NotificationType, bool>? typeSettings,
    bool? allowBatching,
    String? digestFrequency,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool clearQuietHours = false,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? _preferences.enabled,
      categorySettings: categorySettings ?? _preferences.categorySettings,
      typeSettings: typeSettings ?? _preferences.typeSettings,
      allowBatching: allowBatching ?? _preferences.allowBatching,
      digestFrequency: digestFrequency ?? _preferences.digestFrequency,
      quietHoursStart: clearQuietHours
          ? null
          : (quietHoursStart ?? _preferences.quietHoursStart),
      quietHoursEnd: clearQuietHours
          ? null
          : (quietHoursEnd ?? _preferences.quietHoursEnd),
      soundEnabled: soundEnabled ?? _preferences.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? _preferences.vibrationEnabled,
      lastUpdated: DateTime.now(),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Internal model for category display configuration.
class _CategoryItem {
  final NotificationCategory category;
  final String label;
  final IconData icon;

  const _CategoryItem({
    required this.category,
    required this.label,
    required this.icon,
  });
}

const _categoryItems = [
  _CategoryItem(
    category: NotificationCategory.friends,
    label: 'Vänner',
    icon: Icons.people_outline,
  ),
  _CategoryItem(
    category: NotificationCategory.recipes,
    label: 'Recept',
    icon: Icons.restaurant_outlined,
  ),
  _CategoryItem(
    category: NotificationCategory.collaboration,
    label: 'Samarbete',
    icon: Icons.group_work_outlined,
  ),
  _CategoryItem(
    category: NotificationCategory.shopping,
    label: 'Inköp',
    icon: Icons.shopping_cart_outlined,
  ),
  _CategoryItem(
    category: NotificationCategory.social,
    label: 'Social aktivitet',
    icon: Icons.forum_outlined,
  ),
  _CategoryItem(
    category: NotificationCategory.system,
    label: 'System',
    icon: Icons.settings_outlined,
  ),
];
