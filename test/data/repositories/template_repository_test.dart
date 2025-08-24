import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/data/repositories/template_repository.dart';
import 'package:cycle_avatar/data/datasources/local/database_helper.dart';
import 'package:cycle_avatar/domain/entities/template.dart';

void main() {
  group('TemplateRepository Tests', () {
    late TemplateRepository repository;
    late DatabaseHelper databaseHelper;

    setUpAll(() async {
      databaseHelper = DatabaseHelper();
      repository = TemplateRepositoryImpl(databaseHelper);
    });

    tearDownAll(() async {
      await databaseHelper.close();
    });

    test('should create and retrieve template', () async {
      // Given
      final template = Template(
        id: 'test-template-1',
        userId: 'test-user-1',
        name: 'Test Template',
        description: 'A test template',
        exercises: [
          TemplateExercise(
            exerciseId: 'squat',
            sets: 3,
            targetReps: 10,
            restSeconds: 60,
            order: 0,
            primaryMuscleGroups: ['quadriceps'],
            secondaryMuscleGroups: ['glutes'],
          ),
        ],
        createdAt: DateTime.now(),
      );

      // When
      final createdTemplate = await repository.create(template);
      final retrievedTemplate = await repository.findById(template.id);

      // Then
      expect(createdTemplate.id, equals(template.id));
      expect(retrievedTemplate, isNotNull);
      expect(retrievedTemplate!.name, equals(template.name));
      expect(retrievedTemplate.exercises.length, equals(1));
      expect(retrievedTemplate.exercises.first.exerciseId, equals('squat'));
    });

    test('should find templates by user ID', () async {
      // Given
      const userId = 'test-user-2';
      final template1 = Template(
        id: 'template-1',
        userId: userId,
        name: 'Template 1',
        description: 'First template',
        exercises: [],
        createdAt: DateTime.now(),
      );
      final template2 = Template(
        id: 'template-2',
        userId: userId,
        name: 'Template 2',
        description: 'Second template',
        exercises: [],
        createdAt: DateTime.now(),
      );

      await repository.create(template1);
      await repository.create(template2);

      // When
      final userTemplates = await repository.findByUserId(userId);

      // Then
      expect(userTemplates.length, greaterThanOrEqualTo(2));
      expect(userTemplates.any((t) => t.id == 'template-1'), isTrue);
      expect(userTemplates.any((t) => t.id == 'template-2'), isTrue);
    });

    test('should mark template as used', () async {
      // Given
      final template = Template(
        id: 'usage-test-template',
        userId: 'test-user-3',
        name: 'Usage Test Template',
        description: 'Template for testing usage',
        exercises: [],
        createdAt: DateTime.now(),
      );

      await repository.create(template);

      // When
      await repository.markAsUsed(template.id);
      final updatedTemplate = await repository.findById(template.id);

      // Then
      expect(updatedTemplate, isNotNull);
      expect(updatedTemplate!.usageCount, equals(1));
      expect(updatedTemplate.lastUsedAt, isNotNull);
    });
  });
}