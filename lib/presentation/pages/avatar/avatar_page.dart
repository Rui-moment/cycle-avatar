import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/avatar_provider.dart';
import '../../widgets/common/avatar_level_display_widget.dart';
import '../../widgets/common/badge_display_widget.dart';
import '../../../core/l10n/app_localizations.dart';

class AvatarPage extends ConsumerStatefulWidget {
  const AvatarPage({super.key});

  @override
  ConsumerState<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends ConsumerState<AvatarPage> 
    with TickerProviderStateMixin {
  late AnimationController _levelUpAnimationController;
  bool _showLevelUpAnimation = false;

  @override
  void initState() {
    super.initState();
    _levelUpAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _levelUpAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avatarState = ref.watch(avatarProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.avatar),
        elevation: 0,
        actions: [
          // Demo button to trigger level up animation
          IconButton(
            icon: const Icon(Icons.celebration),
            onPressed: _triggerLevelUpAnimation,
            tooltip: 'Demo Level Up',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // In a real app, this would refresh avatar data from the server
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avatarState.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (avatarState.error != null)
                _buildErrorState(context, l10n, avatarState.error!)
              else if (avatarState.avatarState != null) ...[
                // Avatar level display
                AvatarLevelDisplayWidget(
                  avatarState: avatarState.avatarState!,
                  showAnimation: _showLevelUpAnimation,
                ),
                const SizedBox(height: 16),
                
                // Badge display
                BadgeDisplayWidget(
                  avatarState: avatarState.avatarState!,
                  showAnimation: _showLevelUpAnimation,
                ),
                const SizedBox(height: 16),
                
                // Recent achievements section
                _buildRecentAchievements(context, l10n),
              ] else
                _buildNoDataState(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n, String error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading avatar data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(avatarProvider.notifier).clearError();
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No avatar data available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first workout to start growing your avatar!',
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

  Widget _buildRecentAchievements(BuildContext context, AppLocalizations l10n) {
    final avatarState = ref.watch(avatarProvider).avatarState!;
    
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
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Recent level up
            if (avatarState.hasRecentLevelUp) ...[
              _buildActivityItem(
                context,
                Icons.trending_up,
                'Level Up!',
                'You leveled up recently',
                Colors.green,
                avatarState.lastLevelUp,
              ),
              const SizedBox(height: 8),
            ],
            
            // Total growth points milestone
            if (avatarState.totalGrowthPoints > 0)
              _buildActivityItem(
                context,
                Icons.stars,
                'Growth Points',
                '${avatarState.totalGrowthPoints.toStringAsFixed(0)} total points earned',
                Colors.orange,
                null,
              ),
            
            if (!avatarState.hasRecentLevelUp && avatarState.totalGrowthPoints == 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No recent activity. Start working out to see your progress!',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    DateTime? timestamp,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (timestamp != null)
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _triggerLevelUpAnimation() {
    setState(() {
      _showLevelUpAnimation = true;
    });
    
    _levelUpAnimationController.forward().then((_) {
      setState(() {
        _showLevelUpAnimation = false;
      });
      _levelUpAnimationController.reset();
    });
    
    // Show celebration snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Level Up! 🎉'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}