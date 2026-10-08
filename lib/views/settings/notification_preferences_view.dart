import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/views/settings/notification_category_items.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Sentinel value paired with [AnalyticsEvents.notificationPreferenceChanged]
/// when the master toggle flips. Per-category toggles emit the
/// [NotificationCategory.name] (`friends`, `recipes`, ...) so the dashboard
/// can treat `master` as the special-case row.
const String _masterPreferenceKey = 'master';

/// Settings view for notification category toggles and quiet hours.
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: context.l10n.notificationTitle,
      ),
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
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppDimensions.paddingL),
                        // BUT-701: scope keyboard tab-order to this
                        // settings form so Tab walks the toggles and
                        // pickers in visual order. No visual change.
                        child: FocusTraversalGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_systemOff) ...[
                                _buildSystemOffRow(),
                                const SizedBox(height: AppDimensions.spacingLg),
                              ],
                              _buildMasterToggle(),
                              const SizedBox(height: AppDimensions.spacingXl),
                              _buildCategorySection(),
                              const SizedBox(height: AppDimensions.spacingXl),
                              _buildDigestFrequencySection(),
                              const SizedBox(height: AppDimensions.spacingXl),
                              _buildQuietHoursSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// The row at the top when notifications are off in the phone
  /// (produktregler.md:739; Skarmar v12 etapp 3 #behnotiser :570): a 1.5 px
  /// outline, a warning glyph and the text in error red, #9C3B23 light /
  /// #DE9078 dark = cs.error in both schemes, and a way to the system
  /// settings.
  Widget _buildSystemOffRow() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('notification-system-off-row'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cs.error, width: 1.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: ButleryIcon(
                  ButleryIcons.triangleAlert,
                  color: cs.error,
                  size: AppDimensions.iconSizeS,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Text(
                  l10n.notifSystemOffRow,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              button: true,
              label: l10n.a11yOpenSystemSettings,
              excludeSemantics: true,
              child: TextButton(
                key: const ValueKey('notification-system-off-open'),
                onPressed: _openSystemSettings,
                child: Text(l10n.permOpenSettings),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterToggle() {
    final cs = Theme.of(context).colorScheme;

    // The switches take the theme's look: control.checked.background track
    // with a paper thumb in both modes (tokens.json:145-154). The ink thumb
    // on a half-ink track they had vanished on the dark page.
    return SwitchListTile(
      title: Text(
        context.l10n.notificationEnableTitle,
        style: AppTextStyles.titleMedium,
      ),
      subtitle: Text(
        context.l10n.notificationEnableSubtitle,
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
      secondary: ButleryIcon(
        _preferences.enabled ? ButleryIcons.bell : ButleryIcons.bellOff,
        color: cs.onSurface,
        size: AppDimensions.iconSizeL,
      ),
      value: _preferences.enabled,
      onChanged: _systemOff ? null : (value) => _onMasterToggle(value),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.notificationCategoriesTitle,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        ...buildNotificationCategoryItems(
          context,
        ).map((item) => _buildCategoryTile(item)),
      ],
    );
  }

  Widget _buildCategoryTile(NotificationCategoryItem item) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = _preferences.categorySettings[item.category] ?? true;

    // A category that cannot be switched (the master toggle or the system
    // setting is off) is drawn disabled, in text.disabled, never faded
    // (tokens.json:41, :120-123, :198; Butlery tillganglighetshandoff).
    final disabled = !_preferences.enabled || _systemOff;
    final fg = disabled
        ? AppModeColors.textDisabled(cs.brightness)
        : cs.onSurface;

    return SwitchListTile(
      title: Text(
        item.label,
        style: AppTextStyles.titleMedium.copyWith(color: fg),
      ),
      secondary: ButleryIcon(
        item.icon,
        color: fg,
        size: AppDimensions.iconSizeL,
      ),
      value: isEnabled,
      onChanged: !disabled
          ? (value) {
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
            }
          : null,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDigestFrequencySection() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.notificationDigestFrequencyTitle,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          l10n.notificationDigestFrequencySubtitle,
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        InputDecorator(
          decoration: InputDecoration(
            prefixIcon: ButleryIcon(
              ButleryIcons.clock,
              color: cs.onSurface,
              size: AppDimensions.iconSizeL,
            ),
            border: const OutlineInputBorder(),
            contentPadding: AppDimensions.paddingSymmetric16x12,
          ),
          child: DropdownButtonHideUnderline(
            child: PressFill(
              surface: PressSurface.base,
              child: DropdownButton<DigestFrequency>(
                iconEnabledColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                iconDisabledColor: AppModeColors.textDisabled(
                  Theme.of(context).brightness,
                ),
                value: _preferences.digestFrequency,
                isDense: true,
                isExpanded: true,
                items: _digestFrequencyItems(l10n),
                onChanged: _preferences.enabled && !_systemOff
                    ? (value) {
                        if (value != null) {
                          _savePreferences(
                            _copyPreferences(digestFrequency: value),
                          );
                        }
                      }
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Built from [DigestFrequency.values], not a second hand-written list —
  /// the two drifting apart is what broke this dropdown for accounts still
  /// holding the retired `'daily'`. The label switch has no `default` on
  /// purpose: adding a value must be a compile error here, not a blank control
  /// months later.
  List<DropdownMenuItem<DigestFrequency>> _digestFrequencyItems(
    AppLocalizations l10n,
  ) => [
    for (final frequency in DigestFrequency.values)
      DropdownMenuItem(
        value: frequency,
        child: Text(
          switch (frequency) {
            DigestFrequency.never => l10n.notificationDigestFrequencyNever,
            DigestFrequency.weekly => l10n.notificationDigestFrequencyWeekly,
          },
          style: AppTextStyles.titleMedium,
        ),
      ),
  ];

  Widget _buildQuietHoursSection() {
    final cs = Theme.of(context).colorScheme;
    final hasQuietHours =
        _preferences.quietHoursStart != null &&
        _preferences.quietHoursEnd != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.notificationQuietHoursTitle,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        SwitchListTile(
          title: Text(
            context.l10n.notificationQuietHoursEnable,
            style: AppTextStyles.titleMedium,
          ),
          subtitle: Text(
            context.l10n.notificationQuietHoursSubtitle,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          secondary: ButleryIcon(
            ButleryIcons.bellOff,
            color: cs.onSurface,
            size: AppDimensions.iconSizeL,
          ),
          value: hasQuietHours,
          onChanged: _systemOff
              ? null
              : (value) {
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
            label: context.l10n.commonFrom,
            time: startText,
            onTap: () => _pickTime(isStart: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
          ),
          child: ButleryIcon(
            ButleryIcons.arrowRight,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: _buildTimeTile(
            label: context.l10n.commonTo,
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
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: context.l10n.a11yPickTime(label, time),
      button: true,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  time,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
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
