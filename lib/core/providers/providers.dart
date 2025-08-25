import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../data/repositories/pr_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/streak_repository.dart';
import '../../data/repositories/notification_preferences_repository.dart';

// Database provider
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

// Repository providers
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return UserRepositoryImpl(databaseHelper);
});

final workoutSetRepositoryProvider = Provider<WorkoutSetRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return WorkoutSetRepositoryImpl(databaseHelper);
});

final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  final setRepository = ref.watch(workoutSetRepositoryProvider);
  return WorkoutSessionRepositoryImpl(databaseHelper, setRepository);
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return ExerciseRepositoryImpl(databaseHelper);
});

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return TemplateRepositoryImpl(databaseHelper);
});

final prRepositoryProvider = Provider<PRRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return PRRepositoryImpl(databaseHelper);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return NotificationRepositoryImpl(databaseHelper);
});

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return StreakRepositoryImpl(databaseHelper);
});

final notificationPreferencesRepositoryProvider = Provider<NotificationPreferencesRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return NotificationPreferencesRepositoryImpl(databaseHelper);
});

// Workout repository provider (combining session and set repositories)
final workoutRepositoryProvider = Provider<WorkoutSessionRepository>((ref) {
  return ref.watch(workoutSessionRepositoryProvider);
});

// State providers will be added as we implement more features