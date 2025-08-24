import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/template_provider.dart';
import '../../providers/workout_session_provider.dart';
import '../../../domain/entities/template.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../widgets/common/loading_button.dart';

class TemplateDetailPage extends ConsumerStatefulWidget {
  final String templateId;

  const TemplateDetailPage({
    super.key,
    required this.templateId,
  });

  @override
  ConsumerState<TemplateDetailPage> createState() => _TemplateDetailPageState();
}

class _TemplateDetailPageState extends ConsumerState<TemplateDetailPage> {
  @override
  void initState() {
    super.initState();
    
    // Load template details on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(templateProvider.notifier).selectTemplate(widget.templateId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final templateState = ref.watch(templateProvider);
    final template = templateState.selectedTemplate;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(template?.name ?? 'Template'),
        actions: [
          if (template != null) ...[
            // TODO: Check if user owns this template
            PopupMenuButton<String>(
              onSelected: (value) => _handleAction(value, template),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy),
                      SizedBox(width: 8),
                      Text('Copy'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: templateState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : templateState.error != null
              ? _buildErrorView(templateState.error!)
              : template == null
                  ? _buildNotFoundView()
                  : _buildTemplateDetail(template),
      bottomNavigationBar: template != null
          ? _buildBottomActions(template)
          : null,
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(templateProvider.notifier).selectTemplate(widget.templateId);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Template not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'The template you\'re looking for doesn\'t exist or has been deleted.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateDetail(Template template) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template header
          _buildTemplateHeader(template),
          const SizedBox(height: 24),
          
          // Template stats
          _buildTemplateStats(template),
          const SizedBox(height: 24),
          
          // Exercises list
          _buildExercisesList(template),
          const SizedBox(height: 100), // Space for bottom actions
        ],
      ),
    );
  }

  Widget _buildTemplateHeader(Template template) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (template.isPublic)
                  const Chip(
                    label: Text('Public'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            
            if (template.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                template.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Template metadata
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: Icons.fitness_center,
                  label: '${template.totalExercises} exercises',
                ),
                _buildInfoChip(
                  icon: Icons.timer,
                  label: '~${template.estimatedDurationMinutes} min',
                ),
                if (template.usageCount > 0)
                  _buildInfoChip(
                    icon: Icons.trending_up,
                    label: '${template.usageCount} uses',
                  ),
                _buildInfoChip(
                  icon: Icons.category,
                  label: template.workoutSplit,
                ),
              ],
            ),
            
            // Tags
            if (template.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: template.tags.map((tag) => Chip(
                  label: Text(tag),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateStats(Template template) {
    final muscleGroups = template.targetedMuscleGroups.toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Targeted Muscle Groups',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            if (muscleGroups.isEmpty)
              Text(
                'No muscle groups specified',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: muscleGroups.map((muscleGroup) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    muscleGroup.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                )).toList(),
              ),
            
            if (template.totalVolume != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.fitness_center, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated Volume: ${template.totalVolume!.toStringAsFixed(0)} kg',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesList(Template template) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercises (${template.exercises.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (template.exercises.isEmpty)
              Text(
                'No exercises in this template',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: template.exercises.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final exercise = template.exercises[index];
                  return _buildExerciseItem(exercise, index + 1);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(TemplateExercise exercise, int order) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order number
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$order',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Exercise details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseId, // TODO: Get exercise name from exercise repository
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    _buildExerciseDetail('${exercise.sets} sets'),
                    const SizedBox(width: 12),
                    _buildExerciseDetail('${exercise.targetReps} reps'),
                    if (exercise.targetWeight != null) ...[
                      const SizedBox(width: 12),
                      _buildExerciseDetail('${exercise.targetWeight!.toStringAsFixed(1)} kg'),
                    ],
                  ],
                ),
                
                const SizedBox(height: 4),
                _buildExerciseDetail('${exercise.restSeconds}s rest'),
                
                if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                
                if (exercise.isSuperset) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Superset${exercise.supersetGroup != null ? ' (${exercise.supersetGroup})' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseDetail(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(Template template) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: LoadingButton(
                onPressed: () => _startWorkoutFromTemplate(template),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 8),
                    Text('Start Workout'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _copyTemplate(template),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy, size: 18),
                    SizedBox(width: 4),
                    Text('Copy'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(String action, Template template) {
    switch (action) {
      case 'edit':
        context.push('/templates/edit/${template.id}');
        break;
      case 'copy':
        _copyTemplate(template);
        break;
      case 'delete':
        _showDeleteConfirmation(template);
        break;
    }
  }

  void _showDeleteConfirmation(Template template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(templateProvider.notifier).deleteTemplate(template.id);
              context.pop(); // Go back to template list
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _copyTemplate(Template template) async {
    const userId = 'current_user_id'; // Replace with actual user ID
    final copiedTemplate = await ref.read(templateProvider.notifier).copyTemplate(template, userId);
    
    if (copiedTemplate != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template "${template.name}" copied to your templates'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.pushReplacement('/templates/${copiedTemplate.id}'),
          ),
        ),
      );
    }
  }

  void _startWorkoutFromTemplate(Template template) async {
    const userId = 'current_user_id'; // Replace with actual user ID
    final session = await ref.read(templateProvider.notifier).createSessionFromTemplate(
      template.id,
      userId,
    );
    
    if (session != null && mounted) {
      // Start the workout session
      await ref.read(workoutSessionProvider.notifier).startSession(session);
      
      // Navigate to workout page
      if (mounted) {
        context.go('/workout');
      }
    }
  }
}