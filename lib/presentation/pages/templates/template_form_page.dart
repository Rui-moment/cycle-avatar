import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../providers/template_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../../domain/entities/template.dart';
import '../../../domain/entities/exercise.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../widgets/common/loading_button.dart';

class TemplateFormPage extends ConsumerStatefulWidget {
  final String? templateId; // null for create, non-null for edit

  const TemplateFormPage({
    super.key,
    this.templateId,
  });

  @override
  ConsumerState<TemplateFormPage> createState() => _TemplateFormPageState();
}

class _TemplateFormPageState extends ConsumerState<TemplateFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  
  List<TemplateExercise> _exercises = [];
  List<String> _tags = [];
  bool _isPublic = false;
  bool _isLoading = false;
  Template? _originalTemplate;

  bool get isEditing => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTemplateForEditing();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _loadTemplateForEditing() async {
    setState(() => _isLoading = true);
    
    await ref.read(templateProvider.notifier).selectTemplate(widget.templateId!);
    final template = ref.read(templateProvider).selectedTemplate;
    
    if (template != null) {
      setState(() {
        _originalTemplate = template;
        _nameController.text = template.name;
        _descriptionController.text = template.description;
        _exercises = List.from(template.exercises);
        _tags = List.from(template.tags);
        _isPublic = template.isPublic;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template not found')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'Create Template'),
        actions: [
          LoadingButton(
            onPressed: _isLoading ? null : _saveTemplate,
            child: Text(isEditing ? 'Update' : 'Create'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic info section
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),
                    
                    // Exercises section
                    _buildExercisesSection(),
                    const SizedBox(height: 24),
                    
                    // Tags section
                    _buildTagsSection(),
                    const SizedBox(height: 24),
                    
                    // Settings section
                    _buildSettingsSection(),
                    const SizedBox(height: 100), // Space for floating action button
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExerciseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name *',
                hintText: 'e.g., Push Day, Full Body Workout',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Template name is required';
                }
                if (value.trim().length > 100) {
                  return 'Template name is too long (max 100 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your workout template...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value != null && value.length > 500) {
                  return 'Description is too long (max 500 characters)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesSection() {
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
                    'Exercises (${_exercises.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_exercises.isNotEmpty)
                  TextButton.icon(
                    onPressed: _reorderExercises,
                    icon: const Icon(Icons.reorder, size: 18),
                    label: const Text('Reorder'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_exercises.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No exercises added yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the + button to add exercises',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercises.length,
                onReorder: _onReorderExercises,
                itemBuilder: (context, index) {
                  final exercise = _exercises[index];
                  return _buildExerciseItem(exercise, index, key: ValueKey(exercise.exerciseId + index.toString()));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(TemplateExercise exercise, int index, {required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Drag handle
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 12),
            
            // Exercise info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.exerciseId, // TODO: Get exercise name from repository
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${exercise.sets} sets'),
                      const SizedBox(width: 12),
                      Text('${exercise.targetReps} reps'),
                      if (exercise.targetWeight != null) ...[
                        const SizedBox(width: 12),
                        Text('${exercise.targetWeight!.toStringAsFixed(1)} kg'),
                      ],
                    ],
                  ),
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
                ],
              ),
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editExercise(index),
                  tooltip: 'Edit Exercise',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _removeExercise(index),
                  tooltip: 'Remove Exercise',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add tags to help categorize and find your template',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a tag',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addTag(_tagController.text),
                  child: const Text('Add'),
                ),
              ],
            ),
            
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) => Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeTag(tag),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Make Public'),
              subtitle: const Text('Allow other users to see and copy this template'),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseDialog() {
    showDialog(
      context: context,
      builder: (context) => _ExerciseSelectionDialog(
        onExerciseSelected: _addExercise,
      ),
    );
  }

  void _addExercise(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => _ExerciseConfigDialog(
        exercise: exercise,
        onSave: (templateExercise) {
          setState(() {
            _exercises.add(templateExercise);
          });
        },
      ),
    );
  }

  void _editExercise(int index) {
    final exercise = _exercises[index];
    // TODO: Get exercise details from repository
    showDialog(
      context: context,
      builder: (context) => _ExerciseConfigDialog(
        exercise: null, // Would need to fetch exercise details
        initialConfig: exercise,
        onSave: (templateExercise) {
          setState(() {
            _exercises[index] = templateExercise;
          });
        },
      ),
    );
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _onReorderExercises(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final exercise = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, exercise.copyWith(order: newIndex));
      
      // Update order for all exercises
      for (int i = 0; i < _exercises.length; i++) {
        _exercises[i] = _exercises[i].copyWith(order: i);
      }
    });
  }

  void _reorderExercises() {
    // This could open a dedicated reorder page or show instructions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drag exercises by the handle to reorder them'),
      ),
    );
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag)) {
      setState(() {
        _tags.add(trimmedTag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      const userId = 'current_user_id'; // Replace with actual user ID
      
      Template? result;
      if (isEditing && _originalTemplate != null) {
        // Update existing template
        final updatedTemplate = _originalTemplate!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          exercises: _exercises,
          tags: _tags,
          isPublic: _isPublic,
        );
        result = await ref.read(templateProvider.notifier).updateTemplate(updatedTemplate);
      } else {
        // Create new template
        result = await ref.read(templateProvider.notifier).createTemplate(
          userId: userId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          exercises: _exercises,
          tags: _tags,
          isPublic: _isPublic,
        );
      }

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing 
                ? 'Template updated successfully' 
                : 'Template created successfully'),
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Dialog for selecting exercises
class _ExerciseSelectionDialog extends ConsumerWidget {
  final Function(Exercise) onExerciseSelected;

  const _ExerciseSelectionDialog({
    required this.onExerciseSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseState = ref.watch(exerciseProvider);

    return AlertDialog(
      title: const Text('Select Exercise'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: exerciseState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: exerciseState.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exerciseState.exercises[index];
                  return ListTile(
                    title: Text(exercise.getLocalizedName('en')),
                    subtitle: Text(exercise.category),
                    onTap: () {
                      Navigator.of(context).pop();
                      onExerciseSelected(exercise);
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Dialog for configuring exercise parameters
class _ExerciseConfigDialog extends StatefulWidget {
  final Exercise? exercise;
  final TemplateExercise? initialConfig;
  final Function(TemplateExercise) onSave;

  const _ExerciseConfigDialog({
    this.exercise,
    this.initialConfig,
    required this.onSave,
  });

  @override
  State<_ExerciseConfigDialog> createState() => _ExerciseConfigDialogState();
}

class _ExerciseConfigDialogState extends State<_ExerciseConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _restController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  
  bool _isSuperset = false;
  String? _supersetGroup;

  @override
  void initState() {
    super.initState();
    
    final config = widget.initialConfig;
    _setsController = TextEditingController(text: config?.sets.toString() ?? '3');
    _repsController = TextEditingController(text: config?.targetReps.toString() ?? '10');
    _restController = TextEditingController(text: config?.restSeconds.toString() ?? '60');
    _weightController = TextEditingController(text: config?.targetWeight?.toString() ?? '');
    _notesController = TextEditingController(text: config?.notes ?? '');
    _isSuperset = config?.isSuperset ?? false;
    _supersetGroup = config?.supersetGroup;
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _restController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise?.getLocalizedName('en') ?? 'Configure Exercise'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _setsController,
                        decoration: const InputDecoration(
                          labelText: 'Sets *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final sets = int.tryParse(value);
                          if (sets == null || sets <= 0 || sets > 20) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _repsController,
                        decoration: const InputDecoration(
                          labelText: 'Reps *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final reps = int.tryParse(value);
                          if (reps == null || reps <= 0 || reps > 100) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _restController,
                        decoration: const InputDecoration(
                          labelText: 'Rest (seconds)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final rest = int.tryParse(value);
                            if (rest == null || rest < 0 || rest > 3600) {
                              return 'Invalid';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final weight = double.tryParse(value);
                            if (weight == null || weight < 0) {
                              return 'Invalid';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('Superset'),
                  value: _isSuperset,
                  onChanged: (value) => setState(() => _isSuperset = value),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveExercise,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveExercise() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final templateExercise = TemplateExercise(
      exerciseId: widget.exercise?.id ?? widget.initialConfig!.exerciseId,
      sets: int.parse(_setsController.text),
      targetReps: int.parse(_repsController.text),
      restSeconds: int.tryParse(_restController.text) ?? 60,
      order: widget.initialConfig?.order ?? 0,
      primaryMuscleGroups: widget.exercise?.primaryMuscleGroups ?? widget.initialConfig!.primaryMuscleGroups,
      secondaryMuscleGroups: widget.exercise?.secondaryMuscleGroups ?? widget.initialConfig!.secondaryMuscleGroups,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      targetWeight: _weightController.text.trim().isEmpty ? null : double.parse(_weightController.text),
      isSuperset: _isSuperset,
      supersetGroup: _isSuperset ? _supersetGroup : null,
    );

    Navigator.of(context).pop();
    widget.onSave(templateExercise);
  }
}