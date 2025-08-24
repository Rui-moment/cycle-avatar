import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../data/services/data_export_service.dart';
import '../../data/services/data_deletion_service.dart';
import '../../core/providers/providers.dart';

/// Provider for data export service
final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(
    userRepository: ref.read(userRepositoryProvider),
    workoutRepository: ref.read(workoutRepositoryProvider),
    exerciseRepository: ref.read(exerciseRepositoryProvider),
    prRepository: ref.read(prRepositoryProvider),
    templateRepository: ref.read(templateRepositoryProvider),
    notificationRepository: ref.read(notificationRepositoryProvider),
    streakRepository: ref.read(streakRepositoryProvider),
  );
});

/// Provider for data deletion service
final dataDeletionServiceProvider = Provider<DataDeletionService>((ref) {
  return DataDeletionService(
    userRepository: ref.read(userRepositoryProvider),
    workoutRepository: ref.read(workoutRepositoryProvider),
    exerciseRepository: ref.read(exerciseRepositoryProvider),
    prRepository: ref.read(prRepositoryProvider),
    templateRepository: ref.read(templateRepositoryProvider),
    notificationRepository: ref.read(notificationRepositoryProvider),
    streakRepository: ref.read(streakRepositoryProvider),
    notificationPreferencesRepository: ref.read(notificationPreferencesRepositoryProvider),
    databaseHelper: ref.read(databaseHelperProvider),
  );
});

/// State for data management operations
class DataManagementState {
  final bool isExporting;
  final bool isDeleting;
  final double exportProgress;
  final double deletionProgress;
  final String? exportStatus;
  final String? deletionStatus;
  final ExportResult? lastExportResult;
  final DeletionResult? lastDeletionResult;
  final DataSizeInfo? dataSizeInfo;
  final DeletionInfo? deletionInfo;
  final String? error;

  const DataManagementState({
    this.isExporting = false,
    this.isDeleting = false,
    this.exportProgress = 0.0,
    this.deletionProgress = 0.0,
    this.exportStatus,
    this.deletionStatus,
    this.lastExportResult,
    this.lastDeletionResult,
    this.dataSizeInfo,
    this.deletionInfo,
    this.error,
  });

  DataManagementState copyWith({
    bool? isExporting,
    bool? isDeleting,
    double? exportProgress,
    double? deletionProgress,
    String? exportStatus,
    String? deletionStatus,
    ExportResult? lastExportResult,
    DeletionResult? lastDeletionResult,
    DataSizeInfo? dataSizeInfo,
    DeletionInfo? deletionInfo,
    String? error,
  }) {
    return DataManagementState(
      isExporting: isExporting ?? this.isExporting,
      isDeleting: isDeleting ?? this.isDeleting,
      exportProgress: exportProgress ?? this.exportProgress,
      deletionProgress: deletionProgress ?? this.deletionProgress,
      exportStatus: exportStatus ?? this.exportStatus,
      deletionStatus: deletionStatus ?? this.deletionStatus,
      lastExportResult: lastExportResult ?? this.lastExportResult,
      lastDeletionResult: lastDeletionResult ?? this.lastDeletionResult,
      dataSizeInfo: dataSizeInfo ?? this.dataSizeInfo,
      deletionInfo: deletionInfo ?? this.deletionInfo,
      error: error ?? this.error,
    );
  }
}

/// Notifier for data management operations
class DataManagementNotifier extends StateNotifier<DataManagementState> {
  final DataExportService _exportService;
  final DataDeletionService _deletionService;
  final Logger _logger = Logger();

  DataManagementNotifier(this._exportService, this._deletionService)
      : super(const DataManagementState());

  /// Loads data size information
  Future<void> loadDataSizeInfo(String userId) async {
    try {
      final dataSizeInfo = await _exportService.getUserDataSize(userId);
      state = state.copyWith(dataSizeInfo: dataSizeInfo, error: null);
    } catch (e) {
      _logger.e('Failed to load data size info', error: e);
      state = state.copyWith(error: e.toString());
    }
  }

  /// Loads deletion information
  Future<void> loadDeletionInfo(String userId) async {
    try {
      final deletionInfo = await _deletionService.getDeletionInfo(userId);
      state = state.copyWith(deletionInfo: deletionInfo, error: null);
    } catch (e) {
      _logger.e('Failed to load deletion info', error: e);
      state = state.copyWith(error: e.toString());
    }
  }

  /// Exports user data
  Future<void> exportUserData(String userId) async {
    if (state.isExporting) return;

    state = state.copyWith(
      isExporting: true,
      exportProgress: 0.0,
      exportStatus: 'Starting export...',
      error: null,
    );

    try {
      final result = await _exportService.exportUserData(
        userId,
        onProgress: (progress, status) {
          state = state.copyWith(
            exportProgress: progress,
            exportStatus: status,
          );
        },
      );

      state = state.copyWith(
        isExporting: false,
        lastExportResult: result,
        exportProgress: result.success ? 1.0 : 0.0,
        exportStatus: result.success ? 'Export completed' : 'Export failed',
        error: result.success ? null : result.error,
      );

      if (result.success) {
        _logger.i('Data export completed successfully');
      } else {
        _logger.e('Data export failed: ${result.error}');
      }
    } catch (e) {
      _logger.e('Data export failed with exception', error: e);
      state = state.copyWith(
        isExporting: false,
        exportProgress: 0.0,
        exportStatus: 'Export failed',
        error: e.toString(),
      );
    }
  }

  /// Shares the exported file
  Future<void> shareExportFile() async {
    final result = state.lastExportResult;
    if (result == null || !result.success || result.filePath == null) {
      state = state.copyWith(error: 'No export file available to share');
      return;
    }

    try {
      await _exportService.shareExportFile(result.filePath!);
      _logger.i('Export file shared successfully');
    } catch (e) {
      _logger.e('Failed to share export file', error: e);
      state = state.copyWith(error: 'Failed to share export file: $e');
    }
  }

  /// Deletes local user data
  Future<void> deleteLocalUserData(String userId) async {
    if (state.isDeleting) return;

    state = state.copyWith(
      isDeleting: true,
      deletionProgress: 0.0,
      deletionStatus: 'Starting deletion...',
      error: null,
    );

    try {
      final result = await _deletionService.deleteLocalUserData(
        userId,
        onProgress: (progress, status) {
          state = state.copyWith(
            deletionProgress: progress,
            deletionStatus: status,
          );
        },
      );

      state = state.copyWith(
        isDeleting: false,
        lastDeletionResult: result,
        deletionProgress: result.success ? 1.0 : 0.0,
        deletionStatus: result.success ? 'Deletion completed' : 'Deletion failed',
        error: result.success ? null : result.error,
      );

      if (result.success) {
        _logger.i('Local data deletion completed successfully');
      } else {
        _logger.e('Local data deletion failed: ${result.error}');
      }
    } catch (e) {
      _logger.e('Local data deletion failed with exception', error: e);
      state = state.copyWith(
        isDeleting: false,
        deletionProgress: 0.0,
        deletionStatus: 'Deletion failed',
        error: e.toString(),
      );
    }
  }

  /// Deletes complete account (local + server)
  Future<void> deleteCompleteAccount(String userId) async {
    if (state.isDeleting) return;

    state = state.copyWith(
      isDeleting: true,
      deletionProgress: 0.0,
      deletionStatus: 'Starting account deletion...',
      error: null,
    );

    try {
      final result = await _deletionService.deleteCompleteAccount(
        userId,
        onProgress: (progress, status) {
          state = state.copyWith(
            deletionProgress: progress,
            deletionStatus: status,
          );
        },
      );

      state = state.copyWith(
        isDeleting: false,
        lastDeletionResult: result,
        deletionProgress: result.success ? 1.0 : 0.0,
        deletionStatus: result.success ? 'Account deletion completed' : 'Account deletion failed',
        error: result.success ? null : result.error,
      );

      if (result.success) {
        _logger.i('Complete account deletion completed successfully');
      } else {
        _logger.e('Complete account deletion failed: ${result.error}');
      }
    } catch (e) {
      _logger.e('Complete account deletion failed with exception', error: e);
      state = state.copyWith(
        isDeleting: false,
        deletionProgress: 0.0,
        deletionStatus: 'Account deletion failed',
        error: e.toString(),
      );
    }
  }

  /// Deletes all application data (complete reset)
  Future<void> deleteAllApplicationData() async {
    if (state.isDeleting) return;

    state = state.copyWith(
      isDeleting: true,
      deletionProgress: 0.0,
      deletionStatus: 'Starting complete reset...',
      error: null,
    );

    try {
      final result = await _deletionService.deleteAllApplicationData(
        onProgress: (progress, status) {
          state = state.copyWith(
            deletionProgress: progress,
            deletionStatus: status,
          );
        },
      );

      state = state.copyWith(
        isDeleting: false,
        lastDeletionResult: result,
        deletionProgress: result.success ? 1.0 : 0.0,
        deletionStatus: result.success ? 'Complete reset finished' : 'Complete reset failed',
        error: result.success ? null : result.error,
      );

      if (result.success) {
        _logger.i('Complete application data deletion completed successfully');
      } else {
        _logger.e('Complete application data deletion failed: ${result.error}');
      }
    } catch (e) {
      _logger.e('Complete application data deletion failed with exception', error: e);
      state = state.copyWith(
        isDeleting: false,
        deletionProgress: 0.0,
        deletionStatus: 'Complete reset failed',
        error: e.toString(),
      );
    }
  }

  /// Clears any error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Resets the state
  void reset() {
    state = const DataManagementState();
  }
}

/// Provider for data management state
final dataManagementProvider = StateNotifierProvider<DataManagementNotifier, DataManagementState>((ref) {
  final exportService = ref.read(dataExportServiceProvider);
  final deletionService = ref.read(dataDeletionServiceProvider);
  return DataManagementNotifier(exportService, deletionService);
});