import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/recovery_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/common/muscle_group_recovery_widget.dart';
import '../../widgets/common/todays_recommendation_widget.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/performance_utils.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with PerformanceMonitorMixin {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization to avoid blocking initial render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHomeData();
    });
  }

  void _initializeHomeData() {
    if (_isInitialized) return;
    
    measureAsyncOperation('Home page initialization', () async {
      // Initialize recovery states
      ref.read(recoveryProvider.notifier).updateRecoveryStates();
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return measureWidgetBuild('HomePage', () {
      final l10n = AppLocalizations.of(context)!;
      final recoveryState = ref.watch(recoveryProvider);
      final todaysRecommendation = ref.watch(todaysRecommendationProvider);

      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: () => _performRefresh(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Today's recommendation - lazy loaded
                    _LazyWidget(
                      builder: () => TodaysRecommendationWidget(
                        recommendation: todaysRecommendation,
                        onStartWorkout: () => context.go('/workout'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Muscle group recovery status - optimized loading
                    _buildRecoverySection(context, recoveryState, l10n),
                    const SizedBox(height: 24),
                    
                    // Quick actions header
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              
              // Quick actions grid - lazy loaded
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _buildQuickActionsGrid(context, l10n),
              ),
              
              // Bottom padding
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 16),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const _BottomNavigationBar(),
      );
    });
  }

  Future<void> _performRefresh() async {
    return measureAsyncOperation('Home page refresh', () async {
      ref.read(recoveryProvider.notifier).updateRecoveryStates();
      // Add small delay to ensure smooth animation
      await Future.delayed(const Duration(milliseconds: 300));
    });
  }

  Widget _buildRecoverySection(
    BuildContext context, 
    RecoveryStateData recoveryState, 
    AppLocalizations l10n,
  ) {
    if (recoveryState.isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (recoveryState.error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Error loading recovery data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(recoveryState.error!),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.read(recoveryProvider.notifier).clearError();
                  ref.read(recoveryProvider.notifier).updateRecoveryStates();
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    
    return _LazyWidget(
      builder: () => MuscleGroupRecoveryWidget(
        recoveryStates: recoveryState.recoveryStates,
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, AppLocalizations l10n) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      delegate: SliverChildListDelegate([
        _buildQuickActionCard(
          context,
          icon: Icons.play_arrow,
          title: l10n.startWorkout,
          subtitle: 'Begin a new session',
          onTap: () => context.go('/workout'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.library_books,
          title: l10n.templates,
          subtitle: 'Manage workout templates',
          onTap: () => context.go('/templates'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.person,
          title: l10n.avatar,
          subtitle: 'View your progress',
          onTap: () => context.go('/avatar'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.history,
          title: l10n.history,
          subtitle: 'View past workouts',
          onTap: () => context.go('/history'),
        ),
      ]),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lazy loading widget to improve initial render performance
class _LazyWidget extends StatefulWidget {
  final Widget Function() builder;
  
  const _LazyWidget({required this.builder});

  @override
  State<_LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<_LazyWidget> {
  Widget? _child;
  
  @override
  void initState() {
    super.initState();
    // Build widget on next frame to avoid blocking initial render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _child = widget.builder();
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return _child ?? const SizedBox.shrink();
  }
}

class _BottomNavigationBar extends StatelessWidget {
  const _BottomNavigationBar();

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      onTap: (index) {
        // Throttle navigation to prevent rapid taps
        PerformanceUtils.throttle(
          const Duration(milliseconds: 300),
          () {
            switch (index) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/workout');
                break;
              case 2:
                context.go('/avatar');
                break;
              case 3:
                context.go('/history');
                break;
              case 4:
                context.go('/settings');
                break;
            }
          },
        );
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Workout',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Avatar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}