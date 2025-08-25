import 'dart:async';
import 'package:logger/logger.dart';
import '../../../domain/entities/sync_entity.dart';
import 'sync_manager.dart';
import 'conflict_resolver.dart';
import 'sync_retry_manager.dart';
import '../../services/connectivity_service.dart';

/// Manages background synchronization with network monitoring
/// Implements Requirements 6.2, 6.5 - Background sync with network monitoring
class BackgroundSyncService {
  static final Logger _logger = Logger();
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  final SyncManager _syncManager = SyncManager();
  final ConflictResolver _conflictResolver = ConflictResolver();
  final SyncRetryManager _retryManager = SyncRetryManager();
  final ConnectivityService _connectivity = createConnectivityService();

  Timer? _backgroundSyncTimer;
  Timer? _networkCheckTimer;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  
  bool _isInitialized = false;
  bool _isBackgroundSyncEnabled = true;
  bool _isOnline = false;
  ConnectivityStatus _currentConnectivity = ConnectivityStatus.none;
  
  final StreamController<BackgroundSyncStatus> _statusController = 
      StreamController<BackgroundSyncStatus>.broadcast();
  final StreamController<NetworkStatus> _networkStatusController = 
      StreamController<NetworkStatus>.broadcast();

  /// Stream of background sync status updates
  Stream<BackgroundSyncStatus> get statusUpdates => _statusController.stream;
  
  /// Stream of network status updates
  Stream<NetworkStatus> get networkStatusUpdates => _networkStatusController.stream;

  /// Current network status
  NetworkStatus get currentNetworkStatus => NetworkStatus(
    isOnline: _isOnline,
    connectivityResult: _currentConnectivity,
    lastChecked: DateTime.now(),
  );

  /// Whether background sync is enabled
  bool get isBackgroundSyncEnabled => _isBackgroundSyncEnabled;

  /// Initialize the background sync service
  /// Implements Requirement 6.2 - Auto sync trigger
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.w('BackgroundSyncService already initialized');
      return;
    }

    try {
      _logger.i('Initializing BackgroundSyncService');
      
      // Initialize dependencies
      await _syncManager.initialize();
      _retryManager.initialize();
      
      // Check initial connectivity
      await _checkInitialConnectivity();
      
      // Start network monitoring
      _startNetworkMonitoring();
      
      // Start background sync timer
      _startBackgroundSync();
      
      // Start periodic network checks
      _startNetworkHealthChecks();
      
      _isInitialized = true;
      _logger.i('BackgroundSyncService initialized successfully');
      
      _emitStatusUpdate(BackgroundSyncStatus.initialized());
      
    } catch (e) {
      _logger.e('Failed to initialize BackgroundSyncService: $e');
      _emitStatusUpdate(BackgroundSyncStatus.error('Initialization failed: $e'));
      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _logger.i('Disposing BackgroundSyncService');
    
    _backgroundSyncTimer?.cancel();
    _networkCheckTimer?.cancel();
    await _connectivitySubscription?.cancel();
    _connectivity.dispose();
    
    _statusController.close();
    _networkStatusController.close();
    
    _syncManager.dispose();
    _conflictResolver.dispose();
    _retryManager.dispose();
    
    _isInitialized = false;
  }

  /// Enable or disable background sync
  void setBackgroundSyncEnabled(bool enabled) {
    _logger.i('Background sync ${enabled ? 'enabled' : 'disabled'}');
    _isBackgroundSyncEnabled = enabled;
    
    if (enabled && _isOnline) {
      _triggerImmediateSync();
    }
    
    _emitStatusUpdate(BackgroundSyncStatus.configurationChanged(
      backgroundSyncEnabled: enabled,
    ));
  }

  /// Trigger immediate sync if conditions are met
  Future<void> triggerImmediateSync() async {
    if (!_isInitialized) {
      _logger.w('BackgroundSyncService not initialized, cannot trigger sync');
      return;
    }

    if (!_isBackgroundSyncEnabled) {
      _logger.d('Background sync disabled, skipping immediate sync');
      return;
    }

    if (!_isOnline) {
      _logger.d('Device offline, cannot trigger immediate sync');
      return;
    }

    await _performBackgroundSync();
  }

  /// Force sync regardless of network status (for testing)
  Future<SyncResult> forceSyncForTesting() async {
    _logger.w('Forcing sync for testing purposes');
    return await _syncManager.performSync(forceSync: true);
  }

  /// Get sync progress information
  Future<SyncProgress> getSyncProgress() async {
    try {
      final pendingCount = await _syncManager.getPendingSyncCount();
      final failedCount = await _syncManager.getFailedSyncCount();
      final retryStats = await _retryManager.getRetryStatistics();
      
      return SyncProgress(
        pendingCount: pendingCount,
        failedCount: failedCount,
        retryableCount: retryStats.readyForRetryCount,
        permanentlyFailedCount: retryStats.permanentlyFailedCount,
        isOnline: _isOnline,
        isSyncing: _syncManager.currentStatus == SyncStatus.inProgress,
        lastSyncAttempt: DateTime.now(), // Would track this in real implementation
      );
      
    } catch (e) {
      _logger.e('Failed to get sync progress: $e');
      return SyncProgress.empty();
    }
  }

  // Private methods

  /// Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      _currentConnectivity = await _connectivity.checkConnectivity();
      _isOnline = await _performNetworkHealthCheck();
      
      _logger.i('Initial connectivity: ${_currentConnectivity.name}, online: $_isOnline');
      
      _emitNetworkStatusUpdate(NetworkStatus(
        isOnline: _isOnline,
        connectivityResult: _currentConnectivity,
        lastChecked: DateTime.now(),
      ));
      
    } catch (e) {
      _logger.e('Failed to check initial connectivity: $e');
      _isOnline = false;
    }
  }

  /// Start monitoring network connectivity changes
  void _startNetworkMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        _logger.e('Connectivity monitoring error: $error');
      },
    );
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityStatus result) async {
    _logger.d('Connectivity changed: ${result.name}');
    _currentConnectivity = result;
    
    // Perform health check to verify actual internet connectivity
    final wasOnline = _isOnline;
    _isOnline = await _performNetworkHealthCheck();
    
    _emitNetworkStatusUpdate(NetworkStatus(
      isOnline: _isOnline,
      connectivityResult: result,
      lastChecked: DateTime.now(),
    ));
    
    // Trigger sync if we just came online
    if (!wasOnline && _isOnline && _isBackgroundSyncEnabled) {
      _logger.i('Device came online, triggering sync');
      _triggerImmediateSync();
    }
    
    // Update sync status
    if (_isOnline) {
      _emitStatusUpdate(BackgroundSyncStatus.online());
    } else {
      _emitStatusUpdate(BackgroundSyncStatus.offline());
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    // Sync every 5 minutes when online
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isBackgroundSyncEnabled && _isOnline) {
        _performBackgroundSync();
      }
    });
  }

  /// Start periodic network health checks
  void _startNetworkHealthChecks() {
    // Check network health every 30 seconds
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performPeriodicNetworkCheck();
    });
  }

  /// Perform periodic network health check
  void _performPeriodicNetworkCheck() async {
    try {
      final wasOnline = _isOnline;
      _isOnline = await _performNetworkHealthCheck();
      
      if (wasOnline != _isOnline) {
        _logger.d('Network status changed: online=$_isOnline');
        
        _emitNetworkStatusUpdate(NetworkStatus(
          isOnline: _isOnline,
          connectivityResult: _currentConnectivity,
          lastChecked: DateTime.now(),
        ));
        
        if (_isOnline && _isBackgroundSyncEnabled) {
          _triggerImmediateSync();
        }
      }
      
    } catch (e) {
      _logger.e('Periodic network check failed: $e');
    }
  }

  /// Perform actual network health check
  Future<bool> _performNetworkHealthCheck() async {
    if (_currentConnectivity == ConnectivityStatus.none) {
      return false;
    }

    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityStatus.none;
    } catch (e) {
      _logger.d('Network health check failed: $e');
      return false;
    }
  }

  /// Trigger immediate sync
  void _triggerImmediateSync() {
    scheduleMicrotask(() async {
      await _performBackgroundSync();
    });
  }

  /// Perform background sync operation
  Future<void> _performBackgroundSync() async {
    if (!_isOnline || !_isBackgroundSyncEnabled) {
      return;
    }

    try {
      _emitStatusUpdate(BackgroundSyncStatus.syncing());
      
      // Process retry queue first
      final retryableEntities = await _retryManager.processRetryQueue();
      if (retryableEntities.isNotEmpty) {
        _logger.d('Processed ${retryableEntities.length} retryable entities');
      }
      
      // Perform main sync
      final syncResult = await _syncManager.performSync();
      
      _logger.d('Background sync completed: ${syncResult.processedCount} processed, ${syncResult.failedCount} failed');
      
      // Clean up completed sync entities periodically
      if (DateTime.now().minute % 10 == 0) { // Every 10 minutes
        await _syncManager.clearCompletedSyncEntities();
      }
      
      if (syncResult.success) {
        _emitStatusUpdate(BackgroundSyncStatus.syncCompleted(syncResult));
      } else {
        _emitStatusUpdate(BackgroundSyncStatus.syncFailed(syncResult));
      }
      
    } catch (e) {
      _logger.e('Background sync failed: $e');
      _emitStatusUpdate(BackgroundSyncStatus.error('Background sync failed: $e'));
    }
  }

  /// Emit status update
  void _emitStatusUpdate(BackgroundSyncStatus status) {
    _statusController.add(status);
  }

  /// Emit network status update
  void _emitNetworkStatusUpdate(NetworkStatus status) {
    _networkStatusController.add(status);
  }
}

/// Background sync status information
class BackgroundSyncStatus {
  final BackgroundSyncState state;
  final String? message;
  final SyncResult? syncResult;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const BackgroundSyncStatus._({
    required this.state,
    this.message,
    this.syncResult,
    required this.timestamp,
    this.metadata,
  });

  factory BackgroundSyncStatus.initialized() {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.initialized,
      timestamp: DateTime.now(),
    );
  }

  factory BackgroundSyncStatus.online() {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.online,
      message: 'Device is online',
      timestamp: DateTime.now(),
    );
  }

  factory BackgroundSyncStatus.offline() {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.offline,
      message: 'Device is offline',
      timestamp: DateTime.now(),
    );
  }

  factory BackgroundSyncStatus.syncing() {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.syncing,
      message: 'Synchronizing data...',
      timestamp: DateTime.now(),
    );
  }

  factory BackgroundSyncStatus.syncCompleted(SyncResult result) {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.syncCompleted,
      message: 'Sync completed successfully',
      syncResult: result,
      timestamp: DateTime.now(),
    );
  }

  factory BackgroundSyncStatus.syncFailed(SyncResult result) {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.syncFailed,
      message: 'Sync failed',
      syncResult: result,
      timestamp: DateTime.now(),
    );
  }

  factory BackgroundSyncStatus.error(String errorMessage) {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.error,
      message: errorMessage,
      timestamp: DateTime.now(),
    );
  }

  factory BackgroundSyncStatus.configurationChanged({
    required bool backgroundSyncEnabled,
  }) {
    return BackgroundSyncStatus._(
      state: BackgroundSyncState.configurationChanged,
      message: 'Configuration updated',
      timestamp: DateTime.now(),
      metadata: {'backgroundSyncEnabled': backgroundSyncEnabled},
    );
  }
}

/// Background sync states
enum BackgroundSyncState {
  initialized,
  online,
  offline,
  syncing,
  syncCompleted,
  syncFailed,
  error,
  configurationChanged,
}

/// Network status information
class NetworkStatus {
  final bool isOnline;
  final ConnectivityStatus connectivityResult;
  final DateTime lastChecked;
  final String? errorMessage;

  const NetworkStatus({
    required this.isOnline,
    required this.connectivityResult,
    required this.lastChecked,
    this.errorMessage,
  });

  /// Get human-readable connection type
  String get connectionType {
    switch (connectivityResult) {
      case ConnectivityStatus.wifi:
        return 'WiFi';
      case ConnectivityStatus.mobile:
        return 'Mobile Data';
      case ConnectivityStatus.ethernet:
        return 'Ethernet';
      case ConnectivityStatus.none:
        return 'No Connection';
    }
  }

  /// Check if connection is metered (mobile data)
  bool get isMeteredConnection {
    return connectivityResult == ConnectivityStatus.mobile;
  }

  /// Check if connection is reliable for sync
  bool get isReliableForSync {
    return isOnline && (
      connectivityResult == ConnectivityStatus.wifi ||
      connectivityResult == ConnectivityStatus.ethernet
    );
  }
}

/// Sync progress information
class SyncProgress {
  final int pendingCount;
  final int failedCount;
  final int retryableCount;
  final int permanentlyFailedCount;
  final bool isOnline;
  final bool isSyncing;
  final DateTime? lastSyncAttempt;

  const SyncProgress({
    required this.pendingCount,
    required this.failedCount,
    required this.retryableCount,
    required this.permanentlyFailedCount,
    required this.isOnline,
    required this.isSyncing,
    this.lastSyncAttempt,
  });

  factory SyncProgress.empty() {
    return const SyncProgress(
      pendingCount: 0,
      failedCount: 0,
      retryableCount: 0,
      permanentlyFailedCount: 0,
      isOnline: false,
      isSyncing: false,
    );
  }

  /// Get total number of items in sync queue
  int get totalQueueCount => pendingCount + failedCount;

  /// Get sync health score (0-100)
  int get healthScore {
    if (totalQueueCount == 0) return 100;
    
    final successfulCount = totalQueueCount - failedCount;
    return ((successfulCount / totalQueueCount) * 100).round();
  }

  /// Check if sync is healthy
  bool get isHealthy => healthScore >= 80 && permanentlyFailedCount == 0;

  /// Get status message
  String get statusMessage {
    if (isSyncing) return 'Syncing...';
    if (!isOnline) return 'Offline';
    if (totalQueueCount == 0) return 'All synced';
    if (pendingCount > 0) return '$pendingCount items pending';
    if (failedCount > 0) return '$failedCount items failed';
    return 'Ready';
  }
}