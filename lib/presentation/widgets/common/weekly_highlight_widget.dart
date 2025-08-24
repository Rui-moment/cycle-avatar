import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../domain/entities/weekly_highlight.dart';

/// Widget that displays a weekly highlight summary
class WeeklyHighlightWidget extends StatelessWidget {
  final WeeklyHighlight highlight;
  final bool showDetailedStats;
  final bool showTrends;
  final VoidCallback? onTap;
  
  const WeeklyHighlightWidget({
    super.key,
    required this.highlight,
    this.showDetailedStats = true,
    this.showTrends = true,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildKeyHighlights(context),
            if (showDetailedStats) _buildDetailedStats(context),
            if (showTrends) _buildTrendAnalysis(context),
            _buildMotivationalSection(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPerformanceColor(colorScheme),
            _getPerformanceColor(colorScheme).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week ${highlight.weekNumber}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      highlight.weekRangeString,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  highlight.performanceRating.name.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            highlight.performanceDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKeyHighlights(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Highlights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...highlight.keyHighlights.map((highlight) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  highlight.split(' ').first, // Get emoji
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highlight.substring(highlight.indexOf(' ') + 1),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildDetailedStats(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Stats',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Sessions',
                  '${highlight.stats.totalSessions}',
                  Icons.fitness_center,
                  colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Sets',
                  '${highlight.stats.totalSets}',
                  Icons.repeat,
                  colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Volume',
                  '${highlight.stats.totalVolume.toStringAsFixed(0)}kg',
                  Icons.trending_up,
                  colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Avg RPE',
                  highlight.stats.averageRPE.toStringAsFixed(1),
                  Icons.speed,
                  Colors.orange,
                ),
              ),
            ],
          ),
          if (highlight.stats.uniqueExercises > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Exercises',
                    '${highlight.stats.uniqueExercises}',
                    Icons.list,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Avg Duration',
                    '${highlight.stats.averageSessionDuration.toStringAsFixed(0)}min',
                    Icons.timer,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrendAnalysis(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                highlight.trend.trendEmoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Trend Analysis',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                highlight.trend.trendDescription,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _getTrendColor(highlight.trend.overallTrend),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTrendChart(context),
          if (highlight.trend.trendInsights.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...highlight.trend.trendInsights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.insights,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTrendChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final trendData = [
      FlSpot(0, highlight.trend.volumeChange),
      FlSpot(1, highlight.trend.sessionChange),
      FlSpot(2, highlight.trend.intensityChange),
      FlSpot(3, highlight.trend.durationChange),
    ];
    
    return SizedBox(
      height: 100,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colorScheme.outline.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  const labels = ['Volume', 'Sessions', 'Intensity', 'Duration'];
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) return const Text('');
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[index],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: trendData,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final color = spot.y > 0 ? Colors.green : Colors.red;
                  return FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  const labels = ['Volume', 'Sessions', 'Intensity', 'Duration'];
                  final index = spot.x.toInt();
                  final label = index < labels.length ? labels[index] : '';
                  
                  return LineTooltipItem(
                    '$label\n${spot.y.toStringAsFixed(1)}%',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMotivationalSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Motivation',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (highlight.motivationalMessage != null)
            Text(
              highlight.motivationalMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (highlight.improvementSuggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Next Week Focus:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            ...highlight.improvementSuggestions.take(2).map((suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
  
  Color _getPerformanceColor(ColorScheme colorScheme) {
    switch (highlight.performanceRating) {
      case PerformanceRating.excellent:
        return Colors.purple;
      case PerformanceRating.great:
        return Colors.green;
      case PerformanceRating.good:
        return colorScheme.primary;
      case PerformanceRating.fair:
        return Colors.orange;
      case PerformanceRating.needsImprovement:
        return Colors.red;
    }
  }
  
  Color _getTrendColor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.stronglyUp:
        return Colors.green;
      case TrendDirection.up:
        return Colors.lightGreen;
      case TrendDirection.stable:
        return Colors.grey;
      case TrendDirection.down:
        return Colors.orange;
      case TrendDirection.stronglyDown:
        return Colors.red;
    }
  }
}

/// Widget that displays a compact weekly highlight card
class WeeklyHighlightCard extends StatelessWidget {
  final WeeklyHighlight highlight;
  final VoidCallback? onTap;
  
  const WeeklyHighlightCard({
    super.key,
    required this.highlight,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Week ${highlight.weekNumber}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        highlight.weekRangeString,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPerformanceColor(colorScheme).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    highlight.performanceRating.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getPerformanceColor(colorScheme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickStat(context, '${highlight.stats.totalSessions}', 'Sessions'),
                const SizedBox(width: 16),
                _buildQuickStat(context, '${highlight.stats.totalVolume.toStringAsFixed(0)}kg', 'Volume'),
                const SizedBox(width: 16),
                _buildQuickStat(context, '${highlight.newPRs.length}', 'PRs'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickStat(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
  
  Color _getPerformanceColor(ColorScheme colorScheme) {
    switch (highlight.performanceRating) {
      case PerformanceRating.excellent:
        return Colors.purple;
      case PerformanceRating.great:
        return Colors.green;
      case PerformanceRating.good:
        return colorScheme.primary;
      case PerformanceRating.fair:
        return Colors.orange;
      case PerformanceRating.needsImprovement:
        return Colors.red;
    }
  }
}