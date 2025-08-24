import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../domain/entities/avatar_state.dart';
import '../../../core/l10n/app_localizations.dart';

/// Widget for displaying avatar level information with visual representation
class AvatarLevelDisplayWidget extends StatelessWidget {
  final AvatarState avatarState;
  final bool showAnimation;

  const AvatarLevelDisplayWidget({
    super.key,
    required this.avatarState,
    this.showAnimation = false,
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
            // Header
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.avatar,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildOverallLevelBadge(context, l10n),
              ],
            ),
            const SizedBox(height: 16),
            
            // Avatar visual representation
            _buildAvatarVisual(context),
            const SizedBox(height: 16),
            
            // Overall stats
            _buildOverallStats(context, l10n),
            const SizedBox(height: 16),
            
            // Muscle group levels grid
            _buildMuscleGroupLevels(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallLevelBadge(BuildContext context, AppLocalizations l10n) {
    final overallLevel = avatarState.overallLevel;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${l10n.level} ${overallLevel.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarVisual(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.2),
              Theme.of(context).primaryColor.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: Theme.of(context).primaryColor,
            width: 3,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Avatar icon
            Icon(
              Icons.person,
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
            
            // Level indicator around the avatar
            if (showAnimation)
              _buildLevelUpAnimation(context)
            else
              _buildStaticLevelIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticLevelIndicator(BuildContext context) {
    final maxLevel = avatarState.maxLevel;
    
    return Positioned.fill(
      child: CustomPaint(
        painter: LevelRingPainter(
          level: maxLevel,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildLevelUpAnimation(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 2),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: AnimatedLevelRingPainter(
              progress: value,
              level: avatarState.maxLevel,
              color: Theme.of(context).primaryColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverallStats(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            l10n.level,
            avatarState.overallLevel.toStringAsFixed(1),
            Icons.trending_up,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            l10n.growthPoints,
            avatarState.totalGrowthPoints.toStringAsFixed(0),
            Icons.stars,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Badges',
            avatarState.unlockedBadges.length.toString(),
            Icons.emoji_events,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
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
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleGroupLevels(BuildContext context, AppLocalizations l10n) {
    final muscleGroups = avatarState.muscleGroupLevels.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by level descending

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Muscle Group Levels',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: muscleGroups.length,
          itemBuilder: (context, index) {
            final entry = muscleGroups[index];
            final muscleGroupId = entry.key;
            final level = entry.value;
            final progress = avatarState.getProgressToNextLevel(muscleGroupId);
            final isInCooldown = avatarState.isMuscleGroupInCooldown(muscleGroupId);
            
            return _buildMuscleGroupLevelTile(
              context,
              muscleGroupId,
              level,
              progress,
              isInCooldown,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMuscleGroupLevelTile(
    BuildContext context,
    String muscleGroupId,
    int level,
    double progress,
    bool isInCooldown,
  ) {
    final muscleGroupName = _formatMuscleGroupName(muscleGroupId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInCooldown 
              ? Colors.red.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  muscleGroupName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isInCooldown)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Cooldown',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                'Lv. $level',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Progress bar to next level
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              isInCooldown ? Colors.red : Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% to Level ${level + 1}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMuscleGroupName(String muscleGroupId) {
    return muscleGroupId.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}

/// Custom painter for static level ring around avatar
class LevelRingPainter extends CustomPainter {
  final int level;
  final Color color;

  LevelRingPainter({required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw level indicators as small circles around the avatar
    for (int i = 0; i < level && i < 12; i++) {
      final angle = (i * 2 * math.pi) / 12;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for animated level ring
class AnimatedLevelRingPainter extends CustomPainter {
  final double progress;
  final int level;
  final Color color;

  AnimatedLevelRingPainter({
    required this.progress,
    required this.level,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Draw animated sparkles
    for (int i = 0; i < (level * progress).round(); i++) {
      final angle = (i * 2 * math.pi) / 12;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      final sparkleSize = 3 + (2 * math.sin(progress * math.pi));
      
      canvas.drawCircle(
        Offset(x, y),
        sparkleSize,
        Paint()
          ..color = color.withOpacity(progress)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}