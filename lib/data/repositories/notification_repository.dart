import 'package:sqflite_common/sqlite_api.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/notification.dart';
import '../datasources/local/database_helper.dart';
import 'base_repository.dart';

/// Repository interface for Notification operations
abstract class NotificationRepository extends BaseRepository<Notification, String> {
  /// Find notifications by user ID
  Future<List<Notification>> findByUserId(String userId);
  
  /// Get unread notifications for a user
  Future<List<Notification>> getUnreadByUserId(String userId);
  
  /// Get notifications by type for a user
  Future<List<Notification>> getByUserIdAndType(String userId, NotificationType type);
  
  /// Get scheduled notifications that are ready to be sent
  Future<List<Notification>> getReadyToSend();
  
  /// Get pending scheduled notifications
  Future<List<Notification>> getPendingScheduled();
  
  /// Mark notification as read
  Future<void> markAsRead(String id);
  
  /// Mark notification as sent
  Future<void> markAsSent(String id);
  
  /// Mark all notifications as read for a user
  Future<void> markAllAsReadForUser(String userId);
  
  /// Delete old notifications (older than specified days)
  Future<int> deleteOldNotifications(int daysOld);
  
  /// Get notification count by type for analytics
  Future<Map<NotificationType, int>> getNotificationCountsByType(String userId);
  
  /// Get recent notifications (last N days)
  Future<List<Notification>> getRecentNotifications(String userId, int days);
  
  /// Check if a similar notification was sent recently
  Future<bool> hasSimilarRecentNotification(String userId, NotificationType type, Duration withinDuration);
  
  /// Get user engagement score based on notification interactions
  Future<int> getUserEngagementScore(String userId);
}

/// Repository for managing notification data
class NotificationRepositoryImpl extends BaseRepositoryImpl<Notification, String> 
    with RepositoryErrorHandling 
    implements NotificationRepository {
  final DatabaseHelper _databaseHelper;
  
  NotificationRepositoryImpl(this._databaseHelper);
  
  final Logger _logger = Logger();

  @override
  Future<Database> get database => _databaseHelper.database;

  @override
  String get tableName => 'notifications';

  @override
  String getId(Notification entity) => entity.id;

  @override
  Future<Notification> create(Notification entity) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      await db.insert(tableName, toMap(entity));
      _logger.d('Created notification: ${entity.id}');
      return entity;
    }, 'create notification');
  }

  @override
  Future<Notification?> findById(String id) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return fromMap(maps.first);
  }

  @override
  Future<List<Notification>> findAll() async {
    final db = await database;
    final maps = await db.query(tableName, orderBy: 'created_at DESC');
    return maps.map((map) => fromMap(map)).toList();
  }

  @override
  Future<Notification> update(Notification entity) async {
    final db = await database;
    await db.update(
      tableName,
      toMap(entity),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
    return entity;
  }

  @override
  Future<bool> deleteById(String id) async {
    final db = await database;
    final count = await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  /// Create the notifications table
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        scheduled_for INTEGER,
        read_at INTEGER,
        priority TEXT NOT NULL DEFAULT 'normal',
        data TEXT NOT NULL DEFAULT '{}',
        is_read INTEGER NOT NULL DEFAULT 0,
        is_sent INTEGER NOT NULL DEFAULT 0,
        action_url TEXT,
        image_url TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX idx_notifications_user_id ON notifications (user_id)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_notifications_type ON notifications (type)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_notifications_scheduled_for ON notifications (scheduled_for)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_notifications_is_read ON notifications (is_read)
    ''');
  }

  @override
  Future<List<Notification>> findByUserId(String userId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Get unread notifications for a user
  Future<List<Notification>> getUnreadByUserId(String userId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Get notifications by type for a user
  Future<List<Notification>> getByUserIdAndType(
    String userId,
    NotificationType type,
  ) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'user_id = ? AND type = ?',
      whereArgs: [userId, type.name],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Get scheduled notifications that are ready to be sent
  Future<List<Notification>> getReadyToSend() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      tableName,
      where: 'is_sent = 0 AND (scheduled_for IS NULL OR scheduled_for <= ?)',
      whereArgs: [now],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Get pending scheduled notifications
  Future<List<Notification>> getPendingScheduled() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      tableName,
      where: 'is_sent = 0 AND scheduled_for > ?',
      whereArgs: [now],
      orderBy: 'scheduled_for ASC',
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Mark notification as read
  Future<void> markAsRead(String id) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_read': 1,
        'read_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark notification as sent
  Future<void> markAsSent(String id) async {
    final db = await database;
    await db.update(
      tableName,
      {'is_sent': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsReadForUser(String userId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_read': 1,
        'read_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
  }

  /// Delete old notifications (older than specified days)
  Future<int> deleteOldNotifications(int daysOld) async {
    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysOld))
        .millisecondsSinceEpoch;
    
    return await db.delete(
      tableName,
      where: 'created_at < ?',
      whereArgs: [cutoffTime],
    );
  }

  /// Get notification count by type for analytics
  Future<Map<NotificationType, int>> getNotificationCountsByType(
    String userId,
  ) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT type, COUNT(*) as count
      FROM $tableName
      WHERE user_id = ?
      GROUP BY type
    ''', [userId]);

    final counts = <NotificationType, int>{};
    for (final map in maps) {
      final typeString = map['type'] as String;
      final count = map['count'] as int;
      
      try {
        final type = NotificationType.values.firstWhere(
          (t) => t.name == typeString,
        );
        counts[type] = count;
      } catch (e) {
        // Skip unknown notification types
        continue;
      }
    }
    
    return counts;
  }

  /// Get recent notifications (last N days)
  Future<List<Notification>> getRecentNotifications(
    String userId,
    int days,
  ) async {
    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    
    final maps = await db.query(
      tableName,
      where: 'user_id = ? AND created_at >= ?',
      whereArgs: [userId, cutoffTime],
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Check if a similar notification was sent recently
  Future<bool> hasSimilarRecentNotification(
    String userId,
    NotificationType type,
    Duration withinDuration,
  ) async {
    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(withinDuration)
        .millisecondsSinceEpoch;
    
    final maps = await db.query(
      tableName,
      where: 'user_id = ? AND type = ? AND created_at >= ?',
      whereArgs: [userId, type.name, cutoffTime],
      limit: 1,
    );
    
    return maps.isNotEmpty;
  }

  /// Get user engagement score based on notification interactions
  Future<int> getUserEngagementScore(String userId) async {
    final db = await database;
    // Calculate engagement based on read rate and recency
    final totalNotifications = await db.rawQuery('''
      SELECT COUNT(*) as total
      FROM $tableName
      WHERE user_id = ?
    ''', [userId]);
    
    final readNotifications = await db.rawQuery('''
      SELECT COUNT(*) as read_count
      FROM $tableName
      WHERE user_id = ? AND is_read = 1
    ''', [userId]);
    
    final total = (totalNotifications.first['total'] as int?) ?? 0;
    final read = (readNotifications.first['read_count'] as int?) ?? 0;
    
    if (total == 0) return 50; // Default engagement score
    
    // Calculate read rate (0-100)
    final readRate = (read / total * 100).round();
    
    // Adjust based on recent activity
    final recentNotifications = await getRecentNotifications(userId, 7);
    final recentReadCount = recentNotifications.where((n) => n.isRead).length;
    final recentTotal = recentNotifications.length;
    
    if (recentTotal > 0) {
      final recentReadRate = (recentReadCount / recentTotal * 100).round();
      // Weight recent activity more heavily
      return ((readRate * 0.3) + (recentReadRate * 0.7)).round();
    }
    
    return readRate;
  }

  @override
  Map<String, dynamic> toMap(Notification entity) {
    return {
      'id': entity.id,
      'user_id': entity.userId,
      'type': entity.type.name,
      'title': entity.title,
      'body': entity.body,
      'created_at': entity.createdAt.millisecondsSinceEpoch,
      'scheduled_for': entity.scheduledFor?.millisecondsSinceEpoch,
      'read_at': entity.readAt?.millisecondsSinceEpoch,
      'priority': entity.priority.name,
      'data': '{}', // Simplified for now
      'is_read': entity.isRead ? 1 : 0,
      'is_sent': entity.isSent ? 1 : 0,
      'action_url': entity.actionUrl,
      'image_url': entity.imageUrl,
    };
  }

  @override
  Notification fromMap(Map<String, dynamic> map) {
    // Convert milliseconds back to DateTime
    final createdAt = DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int);
    final scheduledFor = map['scheduled_for'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_for'] as int)
        : null;
    final readAt = map['read_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['read_at'] as int)
        : null;
    
    // Convert string back to enum
    final type = NotificationType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => NotificationType.custom,
    );
    
    final priority = NotificationPriority.values.firstWhere(
      (p) => p.name == map['priority'],
      orElse: () => NotificationPriority.normal,
    );
    
    // Convert int back to boolean
    final isRead = (map['is_read'] as int) == 1;
    final isSent = (map['is_sent'] as int) == 1;
    
    return Notification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: type,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: createdAt,
      scheduledFor: scheduledFor,
      readAt: readAt,
      priority: priority,
      data: const {}, // Simplified for now
      isRead: isRead,
      isSent: isSent,
      actionUrl: map['action_url'] as String?,
      imageUrl: map['image_url'] as String?,
    );
  }
}