import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/exercise.dart';
import '../../providers/exercise_provider.dart';

class ExerciseSearchField extends ConsumerStatefulWidget {
  final Exercise? selectedExercise;
  final ValueChanged<Exercise> onExerciseSelected;
  final String? hintText;
  final bool showRecentExercises;
  final bool enableQuickSelection;

  const ExerciseSearchField({
    super.key,
    this.selectedExercise,
    required this.onExerciseSelected,
    this.hintText,
    this.showRecentExercises = true,
    this.enableQuickSelection = true,
  });

  @override
  ConsumerState<ExerciseSearchField> createState() => _ExerciseSearchFieldState();
}

class _ExerciseSearchFieldState extends ConsumerState<ExerciseSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;
  String _searchQuery = '';
  List<Exercise> _recentExercises = [];

  @override
  void initState() {
    super.initState();
    if (widget.selectedExercise != null) {
      _controller.text = widget.selectedExercise!.getLocalizedName('en');
    }
    
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          _showSuggestions = false;
        });
      }
    });

    _loadRecentExercises();
  }

  void _loadRecentExercises() {
    if (widget.showRecentExercises) {
      // Load quick access exercises (recent + favorites)
      ref.read(quickAccessExercisesProvider).whenData((exercises) {
        if (mounted) {
          setState(() {
            _recentExercises = exercises;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(exerciseSearchProvider({
      'query': _searchQuery,
      'locale': 'en', // TODO: Get from localization provider
    }));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick selection chips for recent exercises
        if (widget.enableQuickSelection && _recentExercises.isNotEmpty && _searchQuery.isEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentExercises.length,
              itemBuilder: (context, index) {
                final exercise = _recentExercises[index];
                return Padding(
                  padding: EdgeInsets.only(right: 8, left: index == 0 ? 0 : 0),
                  child: ActionChip(
                    label: Text(
                      exercise.getLocalizedName('en'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    avatar: Icon(
                      _getExerciseIcon(exercise.category),
                      size: 16,
                    ),
                    onPressed: () {
                      _controller.text = exercise.getLocalizedName('en');
                      widget.onExerciseSelected(exercise);
                      _focusNode.unfocus();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Search exercises...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _searchQuery = '';
                        _showSuggestions = false;
                      });
                    },
                    icon: const Icon(Icons.clear),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _showSuggestions = value.isNotEmpty || (_focusNode.hasFocus && value.isEmpty);
            });
          },
          onTap: () {
            setState(() {
              _showSuggestions = _controller.text.isNotEmpty || _recentExercises.isNotEmpty;
            });
          },
        ),
        if (_showSuggestions) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _searchQuery.isEmpty && _recentExercises.isNotEmpty
                ? _buildRecentExercisesList()
                : searchResults.when(
                    data: (exercises) {
                      if (exercises.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No exercises found'),
                        );
                      }
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          return _buildExerciseListTile(exercise);
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $error'),
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentExercisesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Recent Exercises',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _recentExercises.length,
            itemBuilder: (context, index) {
              final exercise = _recentExercises[index];
              return _buildExerciseListTile(exercise, isRecent: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseListTile(Exercise exercise, {bool isRecent = false}) {
    return ListTile(
      dense: true,
      title: Text(
        exercise.getLocalizedName('en'),
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${exercise.category} • ${exercise.equipment.name}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isRecent 
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getExerciseIcon(exercise.category),
          size: 16,
          color: isRecent
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      trailing: isRecent ? const Icon(Icons.history, size: 16) : null,
      onTap: () {
        _controller.text = exercise.getLocalizedName('en');
        setState(() {
          _showSuggestions = false;
        });
        widget.onExerciseSelected(exercise);
        _focusNode.unfocus();
      },
    );
  }

  IconData _getExerciseIcon(String category) {
    switch (category.toLowerCase()) {
      case 'chest':
        return Icons.fitness_center;
      case 'back':
        return Icons.accessibility_new;
      case 'shoulders':
        return Icons.sports_gymnastics;
      case 'arms':
        return Icons.sports_martial_arts;
      case 'legs':
        return Icons.directions_run;
      case 'core':
        return Icons.self_improvement;
      default:
        return Icons.fitness_center;
    }
  }
}