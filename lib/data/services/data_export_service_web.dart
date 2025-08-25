import 'dart:convert';
import 'package:universal_html/html.dart' as html;
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

/// Web implementation of [DataExportService]
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

  /// Exports all user data to JSON format and triggers browser download
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

      onProgress?.call(0.0, 'Initializing export...');

      onProgress?.call(0.1, 'Exporting user profile...');
      final user = await _userRepository.findById(userId);
      if (user == null) {
        throw ExportException('User not found: $userId');
      }
      exportData['user'] = user.toJson();

      onProgress?.call(0.2, 'Exporting workout sessions...');
      final workoutSessions = await _workoutRepository.findByUserId(userId);
      exportData['workoutSessions'] =
          workoutSessions.map((session) => session.toJson()).toList();

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
      exportData['exercises'] =
          exercises.map((exercise) => exercise.toJson()).toList();

      onProgress?.call(0.6, 'Exporting personal records...');
      final prRecords = await _prRepository.findByUserId(userId);
      exportData['prRecords'] = prRecords.map((pr) => pr.toJson()).toList();

      onProgress?.call(0.7, 'Exporting workout templates...');
      final templates = await _templateRepository.findByUserId(userId);
      exportData['templates'] = templates.map((t) => t.toJson()).toList();

      onProgress?.call(0.8, 'Exporting notifications...');
      final notifications = await _notificationRepository.findByUserId(userId);
      exportData['notifications'] =
          notifications.map((n) => n.toJson()).toList();

      onProgress?.call(0.9, 'Exporting streak records...');
      final streakRecords = await _streakRepository.findByUserId(userId);
      exportData['streakRecords'] =
          streakRecords.map((s) => s.toJson()).toList();

      final finalExportData = {
        'metadata': exportMetadata,
        'data': exportData,
      };

      onProgress?.call(0.95, 'Generating JSON file...');
      final jsonString = const JsonEncoder.withIndent('  ').convert(finalExportData);

      onProgress?.call(1.0, 'Preparing download...');
      final url = _triggerDownload(userId, jsonString);

      _logger.i('Data export completed successfully for user: $userId');

      return ExportResult(
        success: true,
        filePath: url,
        fileSize: jsonString.length,
        recordCount: _calculateRecordCount(exportData),
      );
    } catch (e, stackTrace) {
      _logger.e('Data export failed for user: $userId',
          error: e, stackTrace: stackTrace);
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Creates a download link for the exported data
  String _triggerDownload(String userId, String jsonData) {
    final bytes = utf8.encode(jsonData);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'cycleavatar_export_${userId}_$timestamp.json';
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return url;
  }

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

  /// Shares the exported file by triggering another download
  Future<void> shareExportFile(String fileUrl) async {
    final anchor = html.AnchorElement(href: fileUrl)
      ..download = ''
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<DataSizeInfo> getUserDataSize(String userId) async {
    try {
      int totalRecords = 0;
      int totalSize = 0;

      final user = await _userRepository.findById(userId);
      if (user != null) {
        totalRecords += 1;
        totalSize += user.toJson().toString().length;
      }

      final workoutSessions = await _workoutRepository.findByUserId(userId);
      totalRecords += workoutSessions.length;
      totalSize += workoutSessions.fold<int>(
          0, (sum, session) => sum + session.toJson().toString().length);

      final prRecords = await _prRepository.findByUserId(userId);
      totalRecords += prRecords.length;
      totalSize += prRecords.fold(
          0, (sum, pr) => sum + pr.toJson().toString().length);

      final templates = await _templateRepository.findByUserId(userId);
      totalRecords += templates.length;
      totalSize += templates.fold(
          0, (sum, template) => sum + template.toJson().toString().length);

      final notifications = await _notificationRepository.findByUserId(userId);
      totalRecords += notifications.length;
      totalSize += notifications.fold(0,
          (sum, notification) => sum + notification.toJson().toString().length);

      final streakRecords = await _streakRepository.findByUserId(userId);
      totalRecords += streakRecords.length;
      totalSize += streakRecords.fold(
          0, (sum, streak) => sum + streak.toJson().toString().length);

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

  Future<bool> validateExportFile(String fileUrl) async {
    try {
      final content = await html.HttpRequest.getString(fileUrl);
      final data = jsonDecode(content) as Map<String, dynamic>;
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
      _logger.e('Export file validation failed: $fileUrl', error: e);
      return false;
    }
  }
}

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

  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '${fileSize!} B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

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

  String get formattedSize {
    if (approximateSize < 1024) return '${approximateSize} B';
    if (approximateSize < 1024 * 1024) {
      return '${(approximateSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(approximateSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);
  @override
  String toString() => 'ExportException: $message';
}
