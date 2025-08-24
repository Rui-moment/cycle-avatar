import 'package:flutter/material.dart';
import '../../../domain/services/plan_generator.dart';
import '../../../domain/entities/enums.dart';
import '../../../core/l10n/app_localizations.dart';

/// Widget for displaying today's workout recommendation
class TodaysRecommendationWidget extends StatelessWidget {
  final WorkoutPlan? recommendation;
  final VoidCallback? onStartWorkout;

  const TodaysRecommendationWidget({
    super.key,
    this.recommendation,
    this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.todaysRecommendation,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recommendation == null)
              _buildLoadingState(context, l10n)
            else if (recommendation!.isRestDay)
              _buildRestDayRecommendation(context, l10n)
            else
              _buildWorkoutRecommendation(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, AppLocalizations l10n) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildRestDayRecommendation(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.hotel,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rest Day Recommended',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recommendation!.reasoning,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (recommendation!.nextRecommendedTime != null) ...[
          const SizedBox(height: 8),
          Text(
            'Next workout recommended: ${_formatDateTime(recommendation!.nextRecommendedTime!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorkoutRecommendation(BuildContext context, AppLocalizations l10n) {
    final recommendation = this.recommendation!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session type and duration
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getSessionTypeColor(recommendation.sessionType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getSessionTypeColor(recommendation.sessionType).withOpacity(0.3),
                ),
              ),
              child: Text(
                _getSessionTypeName(recommendation.sessionType),
                style: TextStyle(
                  color: _getSessionTypeColor(recommendation.sessionType),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.schedule,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              '${recommendation.estimatedDuration.inMinutes} min',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Target muscle groups
        if (recommendation.targetMuscleGroups.isNotEmpty) ...[
          Text(
            'Target Muscle Groups:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: recommendation.targetMuscleGroups.map((muscleGroup) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatMuscleGroupName(muscleGroup),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Reasoning
        Text(
          recommendation.reasoning,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        
        // Start workout button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onStartWorkout,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startWorkout),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
      case SessionType.endurance:
        return 'Endurance';
      case SessionType.deload:
        return 'Deload';
      case SessionType.template:
        return 'Template';
      case SessionType.custom:
        return 'Custom';
    }
  }

  String _formatMuscleGroupName(String muscleGroupId) {
    return muscleGroupId.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'soon';
    }
  }
}