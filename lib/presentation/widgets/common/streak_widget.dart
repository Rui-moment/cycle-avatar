import 'package:flutter/material.dart';

import '../../../domain/entities/streak_record.dart';

/// Widget that displays streak information and visualization
class StreakWidget extends StatelessWidget {
  final StreakRecord streak;
  final bool showVisualization;
  final bool showMilestones;
  final VoidCallback? onTap;
  
  const StreakWidget({
    super.key,
    required this.streak,
    this.showVisualization = true,
    this.showMilestones = true,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStreakColor(colorScheme).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildStreakInfo(context),
            if (showVisualization) ...[
              const SizedBox(height: 16),
              _buildVisualization(context),
            ],
            if (showMilestones && streak.milestones.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildMilestones(context),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStreakColor(colorScheme).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStreakIcon(),
            color: _getStreakColor(colorScheme),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStreakTitle(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                streak.statusDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        if (streak.isBroken)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'At Risk',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildStreakInfo(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Current',
            '${streak.currentStreak}',
            'days',
            _getStreakColor(colorScheme),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Longest',
            '${streak.longestStreak}',
            'days',
            colorScheme.secondary,
          ),
        ),
        if (streak.nextMilestone != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Next Goal',
              '${streak.daysToNextMilestone}',
              'days to go',
              colorScheme.tertiary,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    String unit,
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
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVisualization(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Show last 14 days of streak
    const daysToShow = 14;
    final now = DateTime.now();
    final streakColor = _getStreakColor(colorScheme);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last $daysToShow Days',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(daysToShow, (index) {
            final dayIndex = daysToShow - 1 - index;
            final date = now.subtract(Duration(days: dayIndex));
            final daysSinceStart = date.difference(streak.streakStartDate).inDays;
            
            // Check if this day was part of the streak
            bool wasStreakDay = false;
            if (streak.isActive) {
              // For active streaks, check if day is within current streak
              final daysSinceLastWorkout = now.difference(streak.lastWorkoutDate).inDays;
              final streakEndDate = streak.lastWorkoutDate.add(Duration(days: 1));
              wasStreakDay = date.isBefore(streakEndDate) && 
                           daysSinceStart >= 0 && 
                           daysSinceStart < streak.currentStreak;
            } else {
              // For ended streaks, check if day was before end date
              wasStreakDay = streak.streakEndDate != null &&
                           date.isBefore(streak.streakEndDate!) &&
                           daysSinceStart >= 0;
            }
            
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: wasStreakDay 
                            ? streakColor
                            : colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: wasStreakDay
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: colorScheme.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
  
  Widget _buildMilestones(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Show only the most recent 3 milestones
    final recentMilestones = List<StreakMilestone>.from(streak.milestones)
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    final milestonesToShow = recentMilestones.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Milestones',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...milestonesToShow.map((milestone) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                milestone.icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatMilestoneDate(milestone.achievedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  Color _getStreakColor(ColorScheme colorScheme) {
    if (streak.isBroken) return Colors.orange;
    if (streak.currentStreak >= 30) return Colors.purple;
    if (streak.currentStreak >= 14) return Colors.green;
    if (streak.currentStreak >= 7) return colorScheme.primary;
    return colorScheme.secondary;
  }
  
  IconData _getStreakIcon() {
    switch (streak.streakType) {
      case StreakType.workout:
        return Icons.fitness_center;
      case StreakType.strength:
        return Icons.fitness_center;
      case StreakType.cardio:
        return Icons.directions_run;
      case StreakType.custom:
        return Icons.star;
    }
  }
  
  String _getStreakTitle() {
    switch (streak.streakType) {
      case StreakType.workout:
        return 'Workout Streak';
      case StreakType.strength:
        return 'Strength Streak';
      case StreakType.cardio:
        return 'Cardio Streak';
      case StreakType.custom:
        return 'Custom Streak';
    }
  }
  
  String _formatMilestoneDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

/// Widget that displays a milestone celebration
class MilestoneCelebrationWidget extends StatefulWidget {
  final StreakMilestone milestone;
  final VoidCallback? onDismiss;
  
  const MilestoneCelebrationWidget({
    super.key,
    required this.milestone,
    this.onDismiss,
  });
  
  @override
  State<MilestoneCelebrationWidget> createState() => _MilestoneCelebrationWidgetState();
}

class _MilestoneCelebrationWidgetState extends State<MilestoneCelebrationWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _scaleController.forward();
    });
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Milestone icon
                      Text(
                        widget.milestone.icon,
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      
                      // Milestone title
                      Text(
                        widget.milestone.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      
                      // Milestone description
                      Text(
                        widget.milestone.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Action button
                      FilledButton.icon(
                        onPressed: widget.onDismiss ?? () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.celebration),
                        label: const Text('Awesome!'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shows a milestone celebration dialog
Future<void> showMilestoneCelebration(
  BuildContext context, {
  required StreakMilestone milestone,
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => MilestoneCelebrationWidget(
      milestone: milestone,
      onDismiss: onDismiss,
    ),
  );
}