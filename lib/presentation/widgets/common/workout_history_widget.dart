import 'package:flutter/material.dart';
import '../../../domain/entities/workout_session.dart';
import '../../../domain/entities/enums.dart';
import '../../../core/l10n/app_localizations.dart';

/// Widget for displaying workout history list
class WorkoutHistoryWidget extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final Function(WorkoutSession)? onSessionTap;
  final bool isCompact;

  const WorkoutHistoryWidget({
    super.key,
    required this.sessions,
    this.onSessionTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (sessions.isEmpty) {
      return _buildEmptyState(context, l10n);
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.recentSessions,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sessions.length} sessions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: isCompact ? (sessions.length > 5 ? 5 : sessions.length) : sessions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionTile(context, l10n, session);
              },
            ),
            
            if (isCompact && sessions.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to full history page
                  },
                  child: Text('View All ${sessions.length} Sessions'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No workout history',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first workout to see your history here!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(
    BuildContext context,
    AppLocalizations l10n,
    WorkoutSession session,
  ) {
    final isCompleted = session.endTime != null;
    final duration = isCompleted 
        ? session.endTime!.difference(session.startTime)
        : null;
    
    return InkWell(
      onTap: onSessionTap != null ? () => onSessionTap!(session) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Session type indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _getSessionTypeColor(session.sessionType),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            
            // Session info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatSessionDate(session.startTime),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getSessionTypeColor(session.sessionType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getSessionTypeName(session.sessionType),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getSessionTypeColor(session.sessionType),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.active.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  Row(
                    children: [
                      _buildSessionStat(
                        context,
                        Icons.fitness_center,
                        '${session.uniqueExercises.length} ${l10n.exercises}',
                      ),
                      const SizedBox(width: 16),
                      _buildSessionStat(
                        context,
                        Icons.repeat,
                        '${session.sets.length} ${l10n.sets}',
                      ),
                      if (duration != null) ...[
                        const SizedBox(width: 16),
                        _buildSessionStat(
                          context,
                          Icons.schedule,
                          _formatDuration(duration),
                        ),
                      ],
                    ],
                  ),
                  
                  if (session.totalVolume > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildSessionStat(
                          context,
                          Icons.trending_up,
                          '${session.totalVolume.toStringAsFixed(0)} kg ${l10n.volume}',
                        ),
                        if (session.averageRPE > 0) ...[
                          const SizedBox(width: 16),
                          _buildSessionStat(
                            context,
                            Icons.speed,
                            'RPE ${session.averageRPE.toStringAsFixed(1)}',
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Arrow indicator
            if (onSessionTap != null)
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStat(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getSessionTypeColor(SessionType sessionType) {
    switch (sessionType) {
      case SessionType.strength:
        return Colors.red;
      case SessionType.hypertrophy:
        return Colors.blue;
      case SessionType.endurance:
        return Colors.purple;
      case SessionType.deload:
        return Colors.orange;
      case SessionType.template:
        return Colors.teal;
      case SessionType.custom:
        return Colors.green;
    }
  }

  String _getSessionTypeName(SessionType sessionType) {
    switch (sessionType) {
      case SessionType.strength:
        return 'Strength';
      case SessionType.hypertrophy:
        return 'Hypertrophy';
      case SessionType.deload:
        return 'Deload';
      case SessionType.endurance:
        return 'Endurance';
      case SessionType.custom:
        return 'Custom';
    }
  }

  String _formatSessionDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (sessionDate.isAtSameMomentAs(today)) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (sessionDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}