import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';

/// Widget for displaying workout statistics and charts
class WorkoutStatisticsWidget extends StatelessWidget {
  final Map<String, dynamic> statistics;
  final bool isCompact;

  const WorkoutStatisticsWidget({
    super.key,
    required this.statistics,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (statistics.isEmpty) {
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
                  Icons.analytics,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Key metrics
            _buildKeyMetrics(context, l10n),
            
            if (!isCompact) ...[
              const SizedBox(height: 20),
              
              // Volume chart
              _buildVolumeChart(context, l10n),
              
              const SizedBox(height: 20),
              
              // Exercise frequency
              _buildExerciseFrequency(context, l10n),
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
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No statistics available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete some workouts to see your statistics!',
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

  Widget _buildKeyMetrics(BuildContext context, AppLocalizations l10n) {
    final totalSessions = statistics['totalSessions'] ?? 0;
    final totalVolume = statistics['totalVolume'] ?? 0.0;
    final averageDuration = statistics['averageDuration'] ?? 0.0;
    final totalSets = statistics['totalSets'] ?? 0;
    final averageRPE = statistics['averageRPE'] ?? 0.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isCompact ? 2 : 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isCompact ? 1.5 : 1.2,
      children: [
        _buildMetricCard(
          context,
          'Total Sessions',
          totalSessions.toString(),
          Icons.fitness_center,
          Colors.blue,
        ),
        _buildMetricCard(
          context,
          l10n.totalVolume,
          '${totalVolume.toStringAsFixed(0)} kg',
          Icons.trending_up,
          Colors.green,
        ),
        if (!isCompact)
          _buildMetricCard(
            context,
            'Avg Duration',
            '${averageDuration.toStringAsFixed(0)} min',
            Icons.schedule,
            Colors.orange,
          ),
        _buildMetricCard(
          context,
          'Total Sets',
          totalSets.toString(),
          Icons.repeat,
          Colors.purple,
        ),
        if (!isCompact)
          _buildMetricCard(
            context,
            l10n.averageRPE,
            averageRPE.toStringAsFixed(1),
            Icons.speed,
            Colors.red,
          ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(BuildContext context, AppLocalizations l10n) {
    final weeklyVolume = statistics['weeklyVolume'] as List<double>? ?? [];
    
    if (weeklyVolume.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No volume data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Volume Trend',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: _buildSimpleBarChart(context, weeklyVolume),
        ),
      ],
    );
  }

  Widget _buildSimpleBarChart(BuildContext context, List<double> data) {
    if (data.isEmpty) return const SizedBox();
    
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return const SizedBox();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.asMap().entries.map((entry) {
        final index = entry.key;
        final value = entry.value;
        final height = (value / maxValue) * 150;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.7),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'W${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExerciseFrequency(BuildContext context, AppLocalizations l10n) {
    final exerciseFrequency = statistics['exerciseFrequency'] as Map<String, int>? ?? {};
    
    if (exerciseFrequency.isEmpty) {
      return const SizedBox();
    }

    // Sort exercises by frequency and take top 5
    final sortedExercises = exerciseFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topExercises = sortedExercises.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Most Frequent Exercises',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topExercises.length,
          itemBuilder: (context, index) {
            final entry = topExercises[index];
            final exerciseId = entry.key;
            final frequency = entry.value;
            final maxFrequency = topExercises.first.value;
            final percentage = frequency / maxFrequency;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatExerciseName(exerciseId),
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$frequency',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatExerciseName(String exerciseId) {
    // Convert exercise ID to readable name
    return exerciseId.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}