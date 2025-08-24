import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/history_provider.dart';
import '../../widgets/common/workout_history_widget.dart';
import '../../widgets/common/workout_statistics_widget.dart';
import '../../../core/l10n/app_localizations.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _demoUserId = 'demo_user';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load history data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutHistoryProvider.notifier).loadHistory(_demoUserId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final historyState = ref.watch(workoutHistoryProvider);
    final filteredSessions = ref.watch(filteredSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.list),
              text: 'Sessions',
            ),
            Tab(
              icon: const Icon(Icons.analytics),
              text: 'Statistics',
            ),
          ],
        ),
        actions: [
          // Filter button
          IconButton(
            icon: Icon(
              historyState.selectedDate != null || historyState.selectedExerciseFilter != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Sessions tab
          _buildSessionsTab(context, l10n, historyState, filteredSessions),
          
          // Statistics tab
          _buildStatisticsTab(context, l10n, historyState),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(
    BuildContext context,
    AppLocalizations l10n,
    WorkoutHistoryState historyState,
    List<WorkoutSession> filteredSessions,
  ) {
    if (historyState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (historyState.error != null) {
      return _buildErrorState(context, l10n, historyState.error!);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(workoutHistoryProvider.notifier).loadHistory(_demoUserId);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active filters display
            if (historyState.selectedDate != null || historyState.selectedExerciseFilter != null)
              _buildActiveFilters(context, l10n, historyState),
            
            // Workout history
            WorkoutHistoryWidget(
              sessions: filteredSessions,
              onSessionTap: (session) => _showSessionDetails(context, session),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab(
    BuildContext context,
    AppLocalizations l10n,
    WorkoutHistoryState historyState,
  ) {
    if (historyState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (historyState.error != null) {
      return _buildErrorState(context, l10n, historyState.error!);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(workoutHistoryProvider.notifier).loadHistory(_demoUserId);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: WorkoutStatisticsWidget(
          statistics: historyState.statistics,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
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
                ref.read(workoutHistoryProvider.notifier).clearError();
                ref.read(workoutHistoryProvider.notifier).loadHistory(_demoUserId);
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters(
    BuildContext context,
    AppLocalizations l10n,
    WorkoutHistoryState historyState,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_alt,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Active Filters',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(workoutHistoryProvider.notifier).clearFilters();
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (historyState.selectedDate != null)
                  _buildFilterChip(
                    context,
                    'Date: ${_formatDate(historyState.selectedDate!)}',
                    () => ref.read(workoutHistoryProvider.notifier).setSelectedDate(null),
                  ),
                if (historyState.selectedExerciseFilter != null)
                  _buildFilterChip(
                    context,
                    'Exercise: ${_formatExerciseName(historyState.selectedExerciseFilter!)}',
                    () => ref.read(workoutHistoryProvider.notifier).filterByExercise(null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Workouts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Filter by Date'),
              subtitle: Text(
                ref.read(workoutHistoryProvider).selectedDate != null
                    ? _formatDate(ref.read(workoutHistoryProvider).selectedDate!)
                    : 'No date selected',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  ref.read(workoutHistoryProvider.notifier).setSelectedDate(date);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Filter by Exercise'),
              subtitle: const Text('Coming soon'),
              enabled: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(workoutHistoryProvider.notifier).clearFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSessionDetails(BuildContext context, WorkoutSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Session Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${_formatDate(session.startTime)}'),
            Text('Type: ${session.sessionType.name}'),
            Text('Sets: ${session.sets.length}'),
            Text('Exercises: ${session.uniqueExercises.length}'),
            if (session.totalVolume > 0)
              Text('Volume: ${session.totalVolume.toStringAsFixed(0)} kg'),
            if (session.endTime != null) ...[
              Text('Duration: ${_formatDuration(session.endTime!.difference(session.startTime))}'),
            ],
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${session.notes}'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatExerciseName(String exerciseId) {
    return exerciseId.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
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