import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/notification_preferences.dart';
import '../../../domain/entities/notification.dart';
import '../../providers/notification_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationState = ref.watch(notificationProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationSettings),
        elevation: 0,
      ),
      body: notificationState.when(
        data: (preferences) => _buildSettingsContent(context, preferences, l10n),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.errorLoadingSettings,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(notificationProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNotificationTypesSection(context, preferences, l10n),
          const SizedBox(height: 24),
          _buildQuietHoursSection(context, preferences, l10n),
          const SizedBox(height: 24),
          _buildEnabledDaysSection(context, preferences, l10n),
          const SizedBox(height: 24),
          _buildNotificationLimitsSection(context, preferences, l10n),
          const SizedBox(height: 24),
          _buildBehaviorSection(context, preferences, l10n),
          const SizedBox(height: 24),
          _buildMuscleGroupSection(context, preferences, l10n),
          const SizedBox(height: 24),
          _buildActionButtons(context, preferences, l10n),
        ],
      ),
    );
  }

  Widget _buildNotificationTypesSection(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.notificationTypes,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildNotificationTypeSwitch(
              context,
              l10n.recoveryNotifications,
              l10n.recoveryNotificationsDescription,
              preferences.recoveryNotifications,
              (value) => _updatePreferences(
                preferences.copyWith(
                  recoveryNotifications: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildNotificationTypeSwitch(
              context,
              l10n.prNotifications,
              l10n.prNotificationsDescription,
              preferences.prNotifications,
              (value) => _updatePreferences(
                preferences.copyWith(
                  prNotifications: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildNotificationTypeSwitch(
              context,
              l10n.streakNotifications,
              l10n.streakNotificationsDescription,
              preferences.streakNotifications,
              (value) => _updatePreferences(
                preferences.copyWith(
                  streakNotifications: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildNotificationTypeSwitch(
              context,
              l10n.weeklyHighlights,
              l10n.weeklyHighlightsDescription,
              preferences.weeklyHighlights,
              (value) => _updatePreferences(
                preferences.copyWith(
                  weeklyHighlights: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildNotificationTypeSwitch(
              context,
              l10n.avatarLevelUpNotifications,
              l10n.avatarLevelUpNotificationsDescription,
              preferences.avatarLevelUpNotifications,
              (value) => _updatePreferences(
                preferences.copyWith(
                  avatarLevelUpNotifications: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildNotificationTypeSwitch(
              context,
              l10n.deloadNotifications,
              l10n.deloadNotificationsDescription,
              preferences.deloadNotifications,
              (value) => _updatePreferences(
                preferences.copyWith(
                  deloadNotifications: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildNotificationTypeSwitch(
              context,
              l10n.badgeNotifications,
              l10n.badgeNotificationsDescription,
              preferences.badgeNotifications,
              (value) => _updatePreferences(
                preferences.copyWith(
                  badgeNotifications: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildNotificationTypeSwitch(
              context,
              l10n.workoutReminders,
              l10n.workoutRemindersDescription,
              preferences.workoutReminders,
              (value) => _updatePreferences(
                preferences.copyWith(
                  workoutReminders: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypeSwitch(
    BuildContext context,
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursSection(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quietHours,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.quietHoursDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    context,
                    l10n.startTime,
                    preferences.quietHoursStart,
                    (hour) => _updatePreferences(
                      preferences.updateQuietHours(hour, preferences.quietHoursEnd),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeSelector(
                    context,
                    l10n.endTime,
                    preferences.quietHoursEnd,
                    (hour) => _updatePreferences(
                      preferences.updateQuietHours(preferences.quietHoursStart, hour),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(
    BuildContext context,
    String label,
    int hour,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showTimePicker(context, hour, onChanged),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Icon(
                  Icons.access_time,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnabledDaysSection(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    final daysOfWeek = [
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.enabledDays,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.enabledDaysDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayNumber = index + 1; // 1 = Monday, 7 = Sunday
                final isEnabled = preferences.enabledDays.contains(dayNumber);
                
                return FilterChip(
                  label: Text(daysOfWeek[index]),
                  selected: isEnabled,
                  onSelected: (selected) {
                    final newEnabledDays = List<int>.from(preferences.enabledDays);
                    if (selected) {
                      newEnabledDays.add(dayNumber);
                    } else {
                      newEnabledDays.remove(dayNumber);
                    }
                    _updatePreferences(preferences.updateEnabledDays(newEnabledDays));
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationLimitsSection(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.notificationLimits,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              context,
              l10n.maxNotificationsPerDay,
              preferences.maxNotificationsPerDay.toDouble(),
              1,
              10,
              1,
              (value) => _updatePreferences(
                preferences.copyWith(
                  maxNotificationsPerDay: value.round(),
                  updatedAt: DateTime.now(),
                ),
              ),
              (value) => value.round().toString(),
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              context,
              l10n.minimumInterval,
              preferences.minimumInterval.inMinutes.toDouble(),
              30,
              480, // 8 hours
              30,
              (value) => _updatePreferences(
                preferences.copyWith(
                  minimumInterval: Duration(minutes: value.round()),
                  updatedAt: DateTime.now(),
                ),
              ),
              (value) {
                final minutes = value.round();
                if (minutes < 60) {
                  return l10n.minutesFormat(minutes);
                } else {
                  final hours = minutes ~/ 60;
                  final remainingMinutes = minutes % 60;
                  if (remainingMinutes == 0) {
                    return l10n.hoursFormat(hours);
                  } else {
                    return l10n.hoursMinutesFormat(hours, remainingMinutes);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(
    BuildContext context,
    String title,
    double value,
    double min,
    double max,
    double divisions,
    ValueChanged<double> onChanged,
    String Function(double) formatter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              formatter(value),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / divisions).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildBehaviorSection(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.notificationBehavior,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildBehaviorSwitch(
              context,
              l10n.enableVibration,
              l10n.enableVibrationDescription,
              preferences.enableVibration,
              (value) => _updatePreferences(
                preferences.copyWith(
                  enableVibration: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildBehaviorSwitch(
              context,
              l10n.enableSound,
              l10n.enableSoundDescription,
              preferences.enableSound,
              (value) => _updatePreferences(
                preferences.copyWith(
                  enableSound: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            _buildBehaviorSwitch(
              context,
              l10n.enableBadge,
              l10n.enableBadgeDescription,
              preferences.enableBadge,
              (value) => _updatePreferences(
                preferences.copyWith(
                  enableBadge: value,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorSwitch(
    BuildContext context,
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleGroupSection(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.muscleGroupNotifications,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.muscleGroupNotificationsDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showMuscleGroupSettings(context, preferences, l10n),
              icon: const Icon(Icons.fitness_center),
              label: Text(l10n.configureMuscleGroups),
            ),
            if (preferences.muscleGroupNotifications.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.customizedMuscleGroups(preferences.muscleGroupNotifications.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _testNotification(context, l10n),
            icon: const Icon(Icons.notifications_active),
            label: Text(l10n.testNotification),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _enableAllNotifications(preferences),
                child: Text(l10n.enableAll),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _disableAllNotifications(preferences),
                child: Text(l10n.disableAll),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTimePicker(
    BuildContext context,
    int currentHour,
    ValueChanged<int> onChanged,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      onChanged(picked.hour);
    }
  }

  void _showMuscleGroupSettings(
    BuildContext context,
    NotificationPreferences preferences,
    AppLocalizations l10n,
  ) {
    // This would show a dialog or navigate to a detailed muscle group settings page
    // For now, we'll show a simple dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.muscleGroupNotifications),
        content: Text(l10n.muscleGroupSettingsComingSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _testNotification(BuildContext context, AppLocalizations l10n) async {
    try {
      await ref.read(notificationProvider.notifier).testNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.testNotificationSent),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.testNotificationFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _enableAllNotifications(NotificationPreferences preferences) {
    _updatePreferences(preferences.enableAll());
  }

  void _disableAllNotifications(NotificationPreferences preferences) {
    _updatePreferences(preferences.disableAll());
  }

  void _updatePreferences(NotificationPreferences preferences) {
    ref.read(notificationProvider.notifier).updatePreferences(preferences);
  }
}