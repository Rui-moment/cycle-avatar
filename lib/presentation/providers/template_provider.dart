import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/template.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/enums.dart';
import '../../data/repositories/template_repository.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../core/providers/providers.dart';

/// State class for template management
class TemplateState {
  final List<Template> userTemplates;
  final List<Template> publicTemplates;
  final List<Template> searchResults;
  final Template? selectedTemplate;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const TemplateState({
    this.userTemplates = const [],
    this.publicTemplates = const [],
    this.searchResults = const [],
    this.selectedTemplate,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  TemplateState copyWith({
    List<Template>? userTemplates,
    List<Template>? publicTemplates,
    List<Template>? searchResults,
    Template? selectedTemplate,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return TemplateState(
      userTemplates: userTemplates ?? this.userTemplates,
      publicTemplates: publicTemplates ?? this.publicTemplates,
      searchResults: searchResults ?? this.searchResults,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Template provider for managing workout templates
class TemplateNotifier extends StateNotifier<TemplateState> {
  final TemplateRepository _templateRepository;
  final ExerciseRepository _exerciseRepository;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  TemplateNotifier(this._templateRepository, this._exerciseRepository) 
      : super(const TemplateState());

  /// Load user's templates
  Future<void> loadUserTemplates(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final templates = await _templateRepository.findByUserId(userId);
      state = state.copyWith(
        userTemplates: templates,
        isLoading: false,
      );
      _logger.d('Loaded ${templates.length} user templates');
    } catch (e) {
      _logger.e('Failed to load user templates: $e');
      state = state.copyWith(
        error: 'Failed to load templates: $e',
        isLoading: false,
      );
    }
  }

  /// Load public templates
  Future<void> loadPublicTemplates() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final templates = await _templateRepository.findPublicTemplates();
      state = state.copyWith(
        publicTemplates: templates,
        isLoading: false,
      );
      _logger.d('Loaded ${templates.length} public templates');
    } catch (e) {
      _logger.e('Failed to load public templates: $e');
      state = state.copyWith(
        error: 'Failed to load public templates: $e',
        isLoading: false,
      );
    }
  }

  /// Search templates
  Future<void> searchTemplates(String query, {String? userId}) async {
    state = state.copyWith(isLoading: true, error: null, searchQuery: query);
    
    try {
      final templates = await _templateRepository.searchTemplates(query, userId: userId);
      state = state.copyWith(
        searchResults: templates,
        isLoading: false,
      );
      _logger.d('Found ${templates.length} templates for query: $query');
    } catch (e) {
      _logger.e('Failed to search templates: $e');
      state = state.copyWith(
        error: 'Failed to search templates: $e',
        isLoading: false,
      );
    }
  }

  /// Clear search results
  void clearSearch() {
    state = state.copyWith(searchResults: [], searchQuery: '');
  }

  /// Select a template
  Future<void> selectTemplate(String templateId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final template = await _templateRepository.findByIdWithExercises(templateId);
      state = state.copyWith(
        selectedTemplate: template,
        isLoading: false,
      );
      _logger.d('Selected template: $templateId');
    } catch (e) {
      _logger.e('Failed to select template: $e');
      state = state.copyWith(
        error: 'Failed to load template: $e',
        isLoading: false,
      );
    }
  }

  /// Create a new template
  Future<Template?> createTemplate({
    required String userId,
    required String name,
    required String description,
    required List<TemplateExercise> exercises,
    List<String> tags = const [],
    bool isPublic = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final template = Template(
        id: _uuid.v4(),
        userId: userId,
        name: name,
        description: description,
        exercises: exercises,
        isPublic: isPublic,
        createdAt: DateTime.now(),
        tags: tags,
      );

      final createdTemplate = await _templateRepository.create(template);
      
      // Update user templates list
      final updatedUserTemplates = [createdTemplate, ...state.userTemplates];
      state = state.copyWith(
        userTemplates: updatedUserTemplates,
        selectedTemplate: createdTemplate,
        isLoading: false,
      );
      
      _logger.d('Created template: ${createdTemplate.id}');
      return createdTemplate;
    } catch (e) {
      _logger.e('Failed to create template: $e');
      state = state.copyWith(
        error: 'Failed to create template: $e',
        isLoading: false,
      );
      return null;
    }
  }

  /// Update an existing template
  Future<Template?> updateTemplate(Template template) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final updatedTemplate = await _templateRepository.update(template);
      
      // Update user templates list
      final updatedUserTemplates = state.userTemplates
          .map((t) => t.id == template.id ? updatedTemplate : t)
          .toList();
      
      state = state.copyWith(
        userTemplates: updatedUserTemplates,
        selectedTemplate: updatedTemplate,
        isLoading: false,
      );
      
      _logger.d('Updated template: ${updatedTemplate.id}');
      return updatedTemplate;
    } catch (e) {
      _logger.e('Failed to update template: $e');
      state = state.copyWith(
        error: 'Failed to update template: $e',
        isLoading: false,
      );
      return null;
    }
  }

  /// Delete a template
  Future<bool> deleteTemplate(String templateId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final success = await _templateRepository.deleteById(templateId);
      
      if (success) {
        // Remove from user templates list
        final updatedUserTemplates = state.userTemplates
            .where((t) => t.id != templateId)
            .toList();
        
        // Clear selected template if it was deleted
        Template? selectedTemplate = state.selectedTemplate;
        if (selectedTemplate?.id == templateId) {
          selectedTemplate = null;
        }
        
        state = state.copyWith(
          userTemplates: updatedUserTemplates,
          selectedTemplate: selectedTemplate,
          isLoading: false,
        );
        
        _logger.d('Deleted template: $templateId');
      }
      
      return success;
    } catch (e) {
      _logger.e('Failed to delete template: $e');
      state = state.copyWith(
        error: 'Failed to delete template: $e',
        isLoading: false,
      );
      return false;
    }
  }

  /// Create a workout session from a template
  Future<WorkoutSession?> createSessionFromTemplate(
    String templateId,
    String userId,
  ) async {
    try {
      final template = await _templateRepository.findByIdWithExercises(templateId);
      if (template == null) {
        throw Exception('Template not found');
      }

      // Mark template as used
      await _templateRepository.markAsUsed(templateId);

      // Create workout session
      final session = WorkoutSession(
        id: _uuid.v4(),
        userId: userId,
        startTime: DateTime.now(),
        sessionType: SessionType.template,
        notes: 'From template: ${template.name}',
        sets: [], // Sets will be added as user logs them
        createdAt: DateTime.now(),
      );

      _logger.d('Created session from template: $templateId');
      return session;
    } catch (e) {
      _logger.e('Failed to create session from template: $e');
      state = state.copyWith(error: 'Failed to start workout from template: $e');
      return null;
    }
  }

  /// Get most used templates for a user
  Future<void> loadMostUsedTemplates(String userId, {int limit = 10}) async {
    try {
      final templates = await _templateRepository.getMostUsedTemplates(userId, limit: limit);
      // You could add this to state if needed for UI
      _logger.d('Loaded ${templates.length} most used templates');
    } catch (e) {
      _logger.e('Failed to load most used templates: $e');
    }
  }

  /// Find templates by muscle groups
  Future<void> findTemplatesByMuscleGroups(List<String> muscleGroupIds) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final templates = await _templateRepository.findByMuscleGroups(muscleGroupIds);
      state = state.copyWith(
        searchResults: templates,
        isLoading: false,
      );
      _logger.d('Found ${templates.length} templates for muscle groups: $muscleGroupIds');
    } catch (e) {
      _logger.e('Failed to find templates by muscle groups: $e');
      state = state.copyWith(
        error: 'Failed to find templates: $e',
        isLoading: false,
      );
    }
  }

  /// Find templates by tags
  Future<void> findTemplatesByTags(List<String> tags) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final templates = await _templateRepository.findByTags(tags);
      state = state.copyWith(
        searchResults: templates,
        isLoading: false,
      );
      _logger.d('Found ${templates.length} templates for tags: $tags');
    } catch (e) {
      _logger.e('Failed to find templates by tags: $e');
      state = state.copyWith(
        error: 'Failed to find templates: $e',
        isLoading: false,
      );
    }
  }

  /// Copy a template for the current user
  Future<Template?> copyTemplate(Template template, String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final copiedTemplate = template.copyForUser(
        newId: _uuid.v4(),
        newUserId: userId,
      );

      final createdTemplate = await _templateRepository.create(copiedTemplate);
      
      // Update user templates list
      final updatedUserTemplates = [createdTemplate, ...state.userTemplates];
      state = state.copyWith(
        userTemplates: updatedUserTemplates,
        isLoading: false,
      );
      
      _logger.d('Copied template: ${template.id} -> ${createdTemplate.id}');
      return createdTemplate;
    } catch (e) {
      _logger.e('Failed to copy template: $e');
      state = state.copyWith(
        error: 'Failed to copy template: $e',
        isLoading: false,
      );
      return null;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear selected template
  void clearSelectedTemplate() {
    state = state.copyWith(selectedTemplate: null);
  }
}

/// Provider for template management
final templateProvider = StateNotifierProvider<TemplateNotifier, TemplateState>((ref) {
  final templateRepository = ref.watch(templateRepositoryProvider);
  final exerciseRepository = ref.watch(exerciseRepositoryProvider);
  return TemplateNotifier(templateRepository, exerciseRepository);
});

/// Provider for template repository
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return TemplateRepositoryImpl(databaseHelper);
});