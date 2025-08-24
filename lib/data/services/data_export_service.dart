import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/user.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/pr_record.dart';
import '../../domain/entities/template.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/streak_record.dart';
import '../repositories/user_repository.dart';
import '../repositories/workout_repository.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/pr_repository.dart';
import '../repositories/template_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/streak_repository.dart';

/// Service for exporting user data
class DataExportService {
  final UserRepository _userRepository;
  final WorkoutSessionRepository _workoutRepository;
  final ExerciseRepository _exerciseRepository;
  final PRRepository _prRepository;
  final TemplateRepository _templateRepository;
  final NotificationRepository _notificationRepository;
  final StreakRepository _streakRepository;
  final Logger _logger = Logger();

  DataExportService({
    required UserRepository userRepository,
    required WorkoutSessionRepository workoutRepository,
    required ExerciseRepository exerciseRepository,
    required PRRepository prRepository,
    required TemplateRepository templateRepository,
    required NotificationRepository notificationRepository,
    required StreakRepository streakRepository,
  })  : _userRepository = userRepository,
        _workoutRepository = workoutRepository,
        _exerciseRepository = exerciseRepository,
        _prRepository = prRepository,
        _templateRepository = templateRepository,
        _notificationRepository = notificationRepository,
        _streakRepository = streakRepository;

  /// Exports all user data to JSON format
  Future<ExportResult> exportUserData(
    String userId, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      _logger.i('Starting data export for user: $userId');
      
      final exportData = <String, dynamic>{};
      final exportMetadata = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportVersion': '1.0.0',
        'userId': userId,
      };

      // Update progress
      onProgress?.call(0.0, 'Initializing export...');

      // Export user data
      onProgress?.call(0.1, 'Exporting user profile...');
      final user = await _userRepository.findById(userId);
      if (user == null) {
        throw ExportException('User not found: $userId');
      }
      exportData['user'] = user.toJson();

      // Export workout sessions
      onProgress?.call(0.2, 'Exporting workout sessions...');
      final workoutSessions = await _workoutRepository.findByUserId(userId);
      exportData['workoutSessions'] = workoutSessions.map((session) => session.toJson()).toList();

      // Export exercises (user's used exercises)
      onProgress?.call(0.4, 'Exporting exercises...');
      final exerciseIds = workoutSessions
          .expand((session) => session.sets)
          .map((set) => set.exerciseId)
          .toSet();
      
      final exercises = <Exercise>[];
      for (final exerciseId in exerciseIds) {
        final exercise = await _exerciseRepository.findById(exerciseId);
        if (exercise != null) {
          exercises.add(exercise);
        }
      }
      exportData['exercises'] = exercises.map((exercise) => exercise.toJson()).toList();

      // Export PR records
      onProgress?.call(0.6, 'Exporting personal records...');
      final prRecords = await _prRepository.findByUserId(userId);
      exportData['prRecords'] = prRecords.map((pr) => pr.toJson()).toList();

      // Export templates
      onProgress?.call(0.7, 'Exporting workout templates...');
      final templates = await _templateRepository.findByUserId(userId);
      exportData['templates'] = templates.map((template) => template.toJson()).toList();

      // Export notifications
      onProgress?.call(0.8, 'Exporting notifications...');
      final notifications = await _notificationRepository.findByUserId(userId);
      exportData['notifications'] = notifications.map((notification) => notification.toJson()).toList();

      // Export streak records
      onProgress?.call(0.9, 'Exporting streak records...');
      final streakRecords = await _streakRepository.findByUserId(userId);
      exportData['streakRecords'] = streakRecords.map((streak) => streak.toJson()).toList();

      // Create final export structure
      final finalExportData = {
        'metadata': exportMetadata,
        'data': exportData,
      };

      // Convert to JSON
      onProgress?.call(0.95, 'Generating JSON file...');
      final jsonString = const JsonEncoder.withIndent('  ').convert(finalExportData);

      // Save to file
      onProgress?.call(1.0, 'Saving export file...');
      final file = await _saveExportFile(userId, jsonString);

      _logger.i('Data export completed successfully for user: $userId');
      
      return ExportResult(
        success: true,
        filePath: file.path,
        fileSize: await file.length(),
        recordCount: _calculateRecordCount(exportData),
      );

    } catch (e, stackTrace) {
      _logger.e('Data export failed for user: $userId', error: e, stackTrace: stackTrace);
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Saves the export data to a file
  Future<File> _saveExportFile(String userId, String jsonData) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'cycleavatar_export_${userId}_$timestamp.json';
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsString(jsonData);
    return file;
  }

  /// Calculates the total number of records in the export
  int _calculateRecordCount(Map<String, dynamic> exportData) {
    int count = 0;
    
    if (exportData['user'] != null) count += 1;
    if (exportData['workoutSessions'] != null) {
      count += (exportData['workoutSessions'] as List).length;
    }
    if (exportData['exercises'] != null) {
      count += (exportData['exercises'] as List).length;
    }
    if (exportData['prRecords'] != null) {
      count += (exportData['prRecords'] as List).length;
    }
    if (exportData['templates'] != null) {
      count += (exportData['templates'] as List).length;
    }
    if (exportData['notifications'] != null) {
      count += (exportData['notifications'] as List).length;
    }
    if (exportData['streakRecords'] != null) {
      count += (exportData['streakRecords'] as List).length;
    }
    
    return count;
  }

  /// Shares the exported file
  Future<void> shareExportFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ExportException('Export file not found: $filePath');
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'CycleAvatar Training Data Export',
        subject: 'My CycleAvatar Training Data',
      );

      _logger.i('Export file shared successfully: $filePath');
    } catch (e) {
      _logger.e('Failed to share export file: $filePath', error: e);
      rethrow;
    }
  }

  /// Gets the size of all user data (for display purposes)
  Future<DataSizeInfo> getUserDataSize(String userId) async {
    try {
      int totalRecords = 0;
      int totalSize = 0; // Approximate size in bytes

      // Count user data
      final user = await _userRepository.findById(userId);
      if (user != null) {
        totalRecords += 1;
        totalSize += user.toJson().toString().length;
      }

      // Count workout sessions
      final workoutSessions = await _workoutRepository.findByUserId(userId);
      totalRecords += workoutSessions.length;
      totalSize += workoutSessions.fold<int>(0, (sum, session) => sum + session.toJson().toString().length);

      // Count PR records
      final prRecords = await _prRepository.findByUserId(userId);
      totalRecords += prRecords.length;
      totalSize += prRecords.fold(0, (sum, pr) => sum + pr.toJson().toString().length);

      // Count templates
      final templates = await _templateRepository.findByUserId(userId);
      totalRecords += templates.length;
      totalSize += templates.fold(0, (sum, template) => sum + template.toJson().toString().length);

      // Count notifications
      final notifications = await _notificationRepository.findByUserId(userId);
      totalRecords += notifications.length;
      totalSize += notifications.fold(0, (sum, notification) => sum + notification.toJson().toString().length);

      // Count streak records
      final streakRecords = await _streakRepository.findByUserId(userId);
      totalRecords += streakRecords.length;
      totalSize += streakRecords.fold(0, (sum, streak) => sum + streak.toJson().toString().length);

      return DataSizeInfo(
        totalRecords: totalRecords,
        approximateSize: totalSize,
        workoutSessions: workoutSessions.length,
        prRecords: prRecords.length,
        templates: templates.length,
        notifications: notifications.length,
        streakRecords: streakRecords.length,
      );

    } catch (e) {
      _logger.e('Failed to calculate user data size for user: $userId', error: e);
      rethrow;
    }
  }

  /// Validates export file integrity
  Future<bool> validateExportFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Check required structure
      if (!data.containsKey('metadata') || !data.containsKey('data')) {
        return false;
      }

      final metadata = data['metadata'] as Map<String, dynamic>;
      if (!metadata.containsKey('exportedAt') || 
          !metadata.containsKey('exportVersion') ||
          !metadata.containsKey('userId')) {
        return false;
      }

      return true;
    } catch (e) {
      _logger.e('Export file validation failed: $filePath', error: e);
      return false;
    }
  }
}

/// Result of a data export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final int? fileSize;
  final int? recordCount;
  final String? error;

  ExportResult({
    required this.success,
    this.filePath,
    this.fileSize,
    this.recordCount,
    this.error,
  });

  /// Gets human-readable file size
  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    
    if (fileSize! < 1024) return '${fileSize!} B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Information about user data size
class DataSizeInfo {
  final int totalRecords;
  final int approximateSize;
  final int workoutSessions;
  final int prRecords;
  final int templates;
  final int notifications;
  final int streakRecords;

  DataSizeInfo({
    required this.totalRecords,
    required this.approximateSize,
    required this.workoutSessions,
    required this.prRecords,
    required this.templates,
    required this.notifications,
    required this.streakRecords,
  });

  /// Gets human-readable size
  String get formattedSize {
    if (approximateSize < 1024) return '${approximateSize} B';
    if (approximateSize < 1024 * 1024) return '${(approximateSize / 1024).toStringAsFixed(1)} KB';
    return '${(approximateSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Exception thrown during export operations
class ExportException implements Exception {
  final String message;
  
  ExportException(this.message);
  
  @override
  String toString() => 'ExportException: $message';
}