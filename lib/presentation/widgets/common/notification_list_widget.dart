import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/notification.dart';
import '../../providers/notification_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';

class NotificationListWidget extends ConsumerWidget {
  final bool showOnlyUnread;
  final int? limit;

  const NotificationListWidget({
    super.key,
    this.showOnlyUnread = false,
    this.limit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return notificationsAsync.when(
      data: (notifications) {
        var filteredNotifications = notifications;
        
        if (showOnlyUnread) {
          filteredNotifications = notifications.where((n) => !n.isRead).toList();
        }
        
        if (limit != null && filteredNotifications.length > limit!) {
          filteredNotifications = filteredNotifications.take(limit!).toList();
        }

        if (filteredNotifications.isEmpty) {
          return _buildEmptyState(context, l10n);
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredNotifications.length,
          itemBuilder: (context, index) {
            final notification = filteredNotifications[index];
            return _buildNotificationTile(context, notification, ref, l10n);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showOnlyUnread ? Icons.notifications_none : Icons.notifications_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            showOnlyUnread ? 'No unread notifications' : 'No notifications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showOnlyUnread 
                ? 'All caught up! Check back later for updates.'
                : 'Notifications will appear here when you receive them.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    Notification notification,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildNotificationIcon(notification),
        title: Text(
          notification.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: notification.isRead 
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatNotificationTime(notification.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: notification.isRead 
            ? null 
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _handleNotificationTap(context, notification, ref),
      ),
    );
  }

  Widget _buildNotificationIcon(Notification notification) {
    IconData iconData;
    Color? iconColor;

    switch (notification.type) {
      case NotificationType.recoveryComplete:
        iconData = Icons.refresh;
        iconColor = Colors.green;
        break;
      case NotificationType.prAchieved:
        iconData = Icons.emoji_events;
        iconColor = Colors.amber;
        break;
      case NotificationType.streakMilestone:
        iconData = Icons.local_fire_department;
        iconColor = Colors.orange;
        break;
      case NotificationType.weeklyHighlight:
        iconData = Icons.bar_chart;
        iconColor = Colors.blue;
        break;
      case NotificationType.avatarLevelUp:
        iconData = Icons.trending_up;
        iconColor = Colors.purple;
        break;
      case NotificationType.deloadRecommended:
        iconData = Icons.pause_circle_outline;
        iconColor = Colors.orange;
        break;
      case NotificationType.badgeUnlocked:
        iconData = Icons.military_tech;
        iconColor = Colors.amber;
        break;
      case NotificationType.workoutReminder:
        iconData = Icons.alarm;
        iconColor = Colors.blue;
        break;
      case NotificationType.custom:
        iconData = Icons.notifications;
        iconColor = null;
        break;
    }

    return CircleAvatar(
      backgroundColor: iconColor?.withOpacity(0.1),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _handleNotificationTap(
    BuildContext context,
    Notification notification,
    WidgetRef ref,
  ) async {
    // Mark as read if not already read
    if (!notification.isRead) {
      final actions = await ref.read(notificationActionsProvider.future);
      await actions.markAsRead(notification.id);
      ref.invalidate(userNotificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    }

    // Handle action URL if present
    if (notification.actionUrl != null) {
      // In a real app, you'd handle deep linking here
      // For now, we'll just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action: ${notification.actionUrl}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Show notification details dialog
    _showNotificationDetails(context, notification);
  }

  void _showNotificationDetails(BuildContext context, Notification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 16),
            Text(
              'Type: ${notification.type.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Priority: ${notification.priority.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Created: ${_formatNotificationTime(notification.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (notification.scheduledFor != null)
              Text(
                'Scheduled: ${_formatNotificationTime(notification.scheduledFor!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (notification.data.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Additional Data:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...notification.data.entries.map((entry) => Text(
                '${entry.key}: ${entry.value}',
                style: Theme.of(context).textTheme.bodySmall,
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}