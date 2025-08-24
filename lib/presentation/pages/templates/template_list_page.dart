import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/template_provider.dart';
import '../../providers/workout_session_provider.dart';
import '../../../domain/entities/template.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../widgets/common/loading_button.dart';

class TemplateListPage extends ConsumerStatefulWidget {
  const TemplateListPage({super.key});

  @override
  ConsumerState<TemplateListPage> createState() => _TemplateListPageState();
}

class _TemplateListPageState extends ConsumerState<TemplateListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load templates on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplates();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadTemplates() {
    // TODO: Get current user ID from user provider
    const userId = 'current_user_id'; // Replace with actual user ID
    ref.read(templateProvider.notifier).loadUserTemplates(userId);
    ref.read(templateProvider.notifier).loadPublicTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final templateState = ref.watch(templateProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.templates),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'My Templates'),
            Tab(text: 'Public Templates'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToCreateTemplate(context),
            tooltip: 'Create Template',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search templates...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(templateProvider.notifier).clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (query) {
                if (query.isNotEmpty) {
                  ref.read(templateProvider.notifier).searchTemplates(
                    query,
                    userId: 'current_user_id', // Replace with actual user ID
                  );
                } else {
                  ref.read(templateProvider.notifier).clearSearch();
                }
              },
            ),
          ),
          
          // Content
          Expanded(
            child: templateState.searchQuery.isNotEmpty
                ? _buildSearchResults(templateState)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserTemplates(templateState),
                      _buildPublicTemplates(templateState),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(TemplateState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(templateProvider.notifier).searchTemplates(
                  state.searchQuery,
                  userId: 'current_user_id',
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No templates found for "${state.searchQuery}"',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final template = state.searchResults[index];
        return _buildTemplateCard(template, isSearchResult: true);
      },
    );
  }

  Widget _buildUserTemplates(TemplateState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTemplates,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.userTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No templates yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first workout template to get started',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToCreateTemplate(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.userTemplates.length,
      itemBuilder: (context, index) {
        final template = state.userTemplates[index];
        return _buildTemplateCard(template, isUserTemplate: true);
      },
    );
  }

  Widget _buildPublicTemplates(TemplateState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTemplates,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.publicTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No public templates available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for community templates',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.publicTemplates.length,
      itemBuilder: (context, index) {
        final template = state.publicTemplates[index];
        return _buildTemplateCard(template, isPublicTemplate: true);
      },
    );
  }

  Widget _buildTemplateCard(
    Template template, {
    bool isUserTemplate = false,
    bool isPublicTemplate = false,
    bool isSearchResult = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToTemplateDetail(context, template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          template.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (template.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            template.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isUserTemplate)
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleTemplateAction(value, template),
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
                  if (isPublicTemplate)
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyTemplate(template),
                      tooltip: 'Copy Template',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Template info
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.fitness_center,
                    label: '${template.totalExercises} exercises',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.timer,
                    label: '~${template.estimatedDurationMinutes} min',
                  ),
                  const SizedBox(width: 8),
                  if (template.usageCount > 0)
                    _buildInfoChip(
                      icon: Icons.trending_up,
                      label: '${template.usageCount} uses',
                    ),
                ],
              ),
              
              // Tags
              if (template.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: template.tags.take(3).map((tag) => Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(fontSize: 12),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      onPressed: () => _startWorkoutFromTemplate(template),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow, size: 18),
                          SizedBox(width: 4),
                          Text('Start Workout'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _navigateToTemplateDetail(context, template),
                    child: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  void _handleTemplateAction(String action, Template template) {
    switch (action) {
      case 'edit':
        _navigateToEditTemplate(context, template);
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
            onPressed: () => _navigateToTemplateDetail(context, copiedTemplate),
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

  void _navigateToCreateTemplate(BuildContext context) {
    context.push('/templates/create');
  }

  void _navigateToEditTemplate(BuildContext context, Template template) {
    context.push('/templates/edit/${template.id}');
  }

  void _navigateToTemplateDetail(BuildContext context, Template template) {
    context.push('/templates/${template.id}');
  }
}