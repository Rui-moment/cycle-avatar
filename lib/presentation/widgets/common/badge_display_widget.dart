import 'package:flutter/material.dart';
import '../../../domain/entities/avatar_state.dart';
import '../../../core/l10n/app_localizations.dart';

/// Widget for displaying unlocked badges and achievements
class BadgeDisplayWidget extends StatelessWidget {
  final AvatarState avatarState;
  final bool showAnimation;

  const BadgeDisplayWidget({
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
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${avatarState.unlockedBadges.length} Badges',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (avatarState.unlockedBadges.isEmpty)
              _buildNoBadgesState(context, l10n)
            else
              _buildBadgeGrid(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBadgesState(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No badges yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete workouts and achieve milestones to unlock badges!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeGrid(BuildContext context, AppLocalizations l10n) {
    // Create demo badges for display
    final badges = _createDemoBadges();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isUnlocked = avatarState.unlockedBadges.contains(badge.id);
        
        return _buildBadgeTile(context, badge, isUnlocked);
      },
    );
  }

  Widget _buildBadgeTile(BuildContext context, BadgeInfo badge, bool isUnlocked) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isUnlocked 
            ? badge.color.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked 
              ? badge.color.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge icon with animation
            if (showAnimation && isUnlocked)
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.4 * value),
                    child: Transform.rotate(
                      angle: value * 0.5,
                      child: child,
                    ),
                  );
                },
                child: _buildBadgeIcon(badge, isUnlocked),
              )
            else
              _buildBadgeIcon(badge, isUnlocked),
            
            const SizedBox(height: 8),
            
            // Badge name
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isUnlocked 
                    ? badge.color
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // Badge description
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 9,
                color: isUnlocked 
                    ? Colors.grey[700]
                    : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(BadgeInfo badge, bool isUnlocked) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnlocked 
            ? badge.color
            : Colors.grey[400],
        boxShadow: isUnlocked ? [
          BoxShadow(
            color: badge.color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Icon(
        badge.icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  List<BadgeInfo> _createDemoBadges() {
    return [
      BadgeInfo(
        id: 'first_workout',
        name: 'First Steps',
        description: 'Complete your first workout',
        icon: Icons.play_arrow,
        color: Colors.green,
      ),
      BadgeInfo(
        id: 'week_streak',
        name: 'Week Warrior',
        description: '7 day workout streak',
        icon: Icons.local_fire_department,
        color: Colors.orange,
      ),
      BadgeInfo(
        id: 'pr_master',
        name: 'PR Master',
        description: 'Set 10 personal records',
        icon: Icons.trending_up,
        color: Colors.blue,
      ),
      BadgeInfo(
        id: 'level_10',
        name: 'Level 10',
        description: 'Reach level 10 in any muscle group',
        icon: Icons.star,
        color: Colors.purple,
      ),
      BadgeInfo(
        id: 'consistency',
        name: 'Consistent',
        description: '30 workouts completed',
        icon: Icons.check_circle,
        color: Colors.teal,
      ),
      BadgeInfo(
        id: 'strength_king',
        name: 'Strength King',
        description: 'Focus on strength training',
        icon: Icons.fitness_center,
        color: Colors.red,
      ),
    ];
  }
}

/// Information about a badge/achievement
class BadgeInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const BadgeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}