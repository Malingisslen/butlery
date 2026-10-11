import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/settings/notification_category_items.dart';
import 'package:butlery/views/settings/notification_preferences/notification_system_off_row.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Sentinel value paired with [AnalyticsEvents.notificationPreferenceChanged]
/// when the master toggle flips. Per-category toggles emit the
/// [NotificationCategory.name] (`friends`, `recipes`, ...) so the dashboard
/// can treat `master` as the special-case row.
const String _masterPreferenceKey = 'master';

/// Notification settings. Every change is saved at once.
class NotificationPreferencesView extends StatefulWidget {
  const NotificationPreferencesView({super.key});

  @override
  State<NotificationPreferencesView> createState() =>
      _NotificationPreferencesViewState();
}

class _NotificationPreferencesViewState
    extends State<NotificationPreferencesView>
    with WidgetsBindingObserver {
  NotificationPreferences _preferences = NotificationPreferences.defaults();
  bool _isLoading = true;
  bool _hasError = false;

  /// Notifications are off for Butlery in the phone's settings. Then no
  /// choice here means anything: a row at the top leads to the system
  /// settings, and the switches stay visible but inactive
  /// (produktregler.md:686,739; Skarmar v12 etapp 3 #behnotiser).
  bool _systemOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _checkSystemPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system settings: read the answer again.
    if (state == AppLifecycleState.resumed) _checkSystemPermission();
  }

  Future<void> _checkSystemPermission() async {
    var off = false;
    try {
      off = await ServiceLocator.get<NotificationPermissionService>()
          .blockedInSystem();
    } catch (_) {
      // Unknown means not off: never hide the switches on a guess.
      off = false;
    }
    if (mounted && off != _systemOff) setState(() => _systemOff = off);
  }

  Future<void> _openSystemSettings() async {
    try {
      await ServiceLocator.get<NotificationPermissionService>()
          .openSystemSettings();
    } catch (_) {}
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
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
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// BUT-414: gate enabling notifications on Android 13+ runtime permission.
  /// If the OS grant is declined we still persist the preference flip off —
  /// never hard-gate the rest of the settings surface.
  Future<void> _onMasterToggle(bool wantEnabled) async {
    if (wantEnabled) {
      final permissionService =
          ServiceLocator.get<NotificationPermissionService>();
      final granted = await permissionService.requestIfNeeded(context);
      if (!granted) {
        // Surface the current OFF state; the service has already shown a
        // rationale or settings snackbar as appropriate.
        if (mounted) {
          setState(() => _preferences = _copyPreferences(enabled: false));
        }
        return;
      }
    }
    await _savePreferences(_copyPreferences(enabled: wantEnabled));
    _logPreferenceChange(category: _masterPreferenceKey, enabled: wantEnabled);
  }

  /// BUT-655: opt-in / opt-out rate tracking. Fires on category-level boolean
  /// toggles (master + per-category). Digest frequency and quiet hours are
  /// non-boolean or non-category prefs and stay out of this event's
  /// surface. OS-level permission grant outcomes are tracked
  /// separately by `NotificationPermissionService`.
  void _logPreferenceChange({required String category, required bool enabled}) {
    AnalyticsService.tryLog(
      AnalyticsEvents.notificationPreferenceChanged,
      parameters: {
        'category': category,
        'enabled': enabled,
        'source': 'settings',
      },
    );
  }

  Future<void> _savePreferences(NotificationPreferences updated) async {
    // Optimistic update, but remember the persisted value so a failed save
    // can be reverted — otherwise the UI shows a toggle as changed while the
    // stored value is the opposite, and the user wrongly believes it took.
    final previous = _preferences;
    setState(() => _preferences = updated);
    try {
      final service = ServiceLocator.get<NotificationService>();
      await service.updatePreferences(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _preferences = previous);
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.notificationSaveError,
        );
      }
      return;
    }
    if (mounted) {
      SnackBarUtils.showSuccess(context, context.l10n.allergenSettingsSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ButleryPage.undersida(
      title: context.l10n.settingsNotificationSettings,
      backTo: context.l10n.settingsAppTitle,
      lightBar: true,
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(
            child: _isLoading
                ? StateWidget.loading(
                    message: context.l10n.loadingNotificationPreferences,
                  )
                : _hasError
                ? StateWidget.error(
                    message: context.l10n.errorCouldNotLoad(
                      'aviseringsinställningar',
                    ),
                    actionLabel: context.l10n.commonRetry,
                    onAction: _loadPreferences,
                  )
                // BUT-701: scope keyboard tab-order to this form so Tab
                // walks the rows in visual order.
                : FocusTraversalGroup(
                    child: ListView(
                      padding: ButleryPageBody.margin(
                        context,
                        bottom: AppDimensions.space24,
                      ),
                      children: [
                        if (_systemOff)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppDimensions.space16,
                            ),
                            child: NotificationSystemOffRow(
                              onOpenSettings: _openSystemSettings,
                            ),
                          ),
                        _buildMasterSection(),
                        _buildCategorySection(),
                        _buildCategoryFootnote(),
                        _buildDigestSection(),
                        _buildQuietHoursSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterSection() {
    return ButleryListSection(
      rows: [
        ButleryListRow.toggle(
          label: context.l10n.notifAllowRow,
          emphasis: true,
          checked: _preferences.enabled,
          enabled: !_systemOff,
          onChanged: _onMasterToggle,
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    // A category that cannot be switched (the master toggle or the system
    // setting is off) is drawn disabled, never faded.
    final disabled = !_preferences.enabled || _systemOff;
    return ButleryListSection(
      title: context.l10n.notifCategoriesSection,
      rows: [
        for (final item in buildNotificationCategoryItems(context))
          ButleryListRow.toggle(
            label: item.label,
            checked: _preferences.categorySettings[item.category] ?? true,
            enabled: !disabled,
            onChanged: (value) {
              final updatedSettings = Map<NotificationCategory, bool>.from(
                _preferences.categorySettings,
              );
              updatedSettings[item.category] = value;
              _savePreferences(
                _copyPreferences(categorySettings: updatedSettings),
              );
              _logPreferenceChange(
                category: item.category.name,
                enabled: value,
              );
            },
          ),
      ],
    );
  }

  Widget _buildCategoryFootnote() {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space12),
      child: Text(
        context.l10n.notifCategoriesFootnote,
        style: AppTextStyles.captionBase.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// The label switch has no `default` on purpose: adding a [DigestFrequency]
  /// must be a compile error here, not a blank control months later.
  String _digestLabel(DigestFrequency frequency) {
    final l10n = context.l10n;
    return switch (frequency) {
      DigestFrequency.never => l10n.notificationDigestFrequencyNever,
      DigestFrequency.weekly => l10n.notificationDigestFrequencyWeekly,
    };
  }

  Widget _buildDigestSection() {
    final label = context.l10n.notifDigestRow;
    final current = _digestLabel(_preferences.digestFrequency);
    final active = _preferences.enabled && !_systemOff;
    return ButleryListSection(
      title: context.l10n.notifDigestSection,
      rows: [
        if (active)
          ButleryListRow(
            label: label,
            value: current,
            onTap: _pickDigestFrequency,
          )
        else
          ButleryListRow.info(label: label, value: current),
      ],
    );
  }

  Future<void> _pickDigestFrequency() async {
    // Built from DigestFrequency.values, not a second hand-written list: the
    // two drifting apart once broke this control for accounts still holding a
    // retired value.
    final picked = await showButleryChoiceSheet<DigestFrequency>(
      context,
      title: context.l10n.notificationDigestFrequencyTitle,
      options: [
        for (final frequency in DigestFrequency.values)
          (frequency, _digestLabel(frequency)),
      ],
      selected: _preferences.digestFrequency,
    );
    if (picked == null || !mounted) return;
    if (picked != _preferences.digestFrequency) {
      await _savePreferences(_copyPreferences(digestFrequency: picked));
    }
  }

  Widget _buildQuietHoursSection() {
    final l10n = context.l10n;
    final start = _preferences.quietHoursStart;
    final end = _preferences.quietHoursEnd;
    return ButleryListSection(
      title: l10n.notificationQuietHoursTitle,
      rows: [
        ButleryListRow.toggle(
          label: l10n.notificationQuietHoursEnable,
          subtitle: l10n.notificationQuietHoursSubtitle,
          checked: start != null && end != null,
          enabled: !_systemOff,
          onChanged: (value) => _savePreferences(
            value
                ? _copyPreferences(
                    // Enable with defaults 22:00-08:00
                    quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
                    quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
                  )
                : _copyPreferences(clearQuietHours: true),
          ),
        ),
        if (start != null && end != null) ...[
          ButleryListRow(
            label: l10n.commonFrom,
            value: _formatTime(start),
            onTap: () => _pickTime(isStart: true),
          ),
          ButleryListRow(
            label: l10n.commonTo,
            value: _formatTime(end),
            onTap: () => _pickTime(isStart: false),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? _preferences.quietHoursStart ?? const TimeOfDay(hour: 22, minute: 0)
        : _preferences.quietHoursEnd ?? const TimeOfDay(hour: 8, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      switchToInputEntryModeIcon: const ButleryIcon(ButleryIcons.pencil),
      switchToTimerEntryModeIcon: const ButleryIcon(ButleryIcons.clock),
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

  /// Manual copyWith since the model doesn't provide one.
  /// Using flags for nullable fields that need explicit clearing.
  NotificationPreferences _copyPreferences({
    bool? enabled,
    Map<NotificationCategory, bool>? categorySettings,
    DigestFrequency? digestFrequency,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool clearQuietHours = false,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? _preferences.enabled,
      categorySettings: categorySettings ?? _preferences.categorySettings,
      typeSettings: _preferences.typeSettings,
      allowBatching: _preferences.allowBatching,
      digestFrequency: digestFrequency ?? _preferences.digestFrequency,
      quietHoursStart: clearQuietHours
          ? null
          : (quietHoursStart ?? _preferences.quietHoursStart),
      quietHoursEnd: clearQuietHours
          ? null
          : (quietHoursEnd ?? _preferences.quietHoursEnd),
      lastUpdated: clock.now(),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
