import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../lib/data/datasources/local/database_helper.dart';
import '../../../lib/data/repositories/user_repository.dart';
import '../../../lib/domain/entities/user.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late UserRepository userRepository;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    userRepository = UserRepositoryImpl(databaseHelper);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('UserRepository', () {
    final testUser = User(
      id: 'test_user_1',
      email: 'test@example.com',
      displayName: 'Test User',
      createdAt: DateTime.now(),
      preferredLanguage: 'en',
      isActive: true,
    );

    group('Create Operations', () {
      test('should create user successfully', () async {
        final createdUser = await userRepository.create(testUser);
        
        expect(createdUser, equals(testUser));
        
        // Verify user was saved to database
        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser, isNotNull);
        expect(foundUser!.email, equals(testUser.email));
      });

      test('should throw exception when creating user with invalid data', () async {
        final invalidUser = User(
          id: '',
          email: 'invalid-email',
          displayName: '',
          createdAt: DateTime.now(),
        );

        expect(
          () => userRepository.create(invalidUser),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should throw exception when creating user with duplicate email', () async {
        await userRepository.create(testUser);

        final duplicateUser = testUser.copyWith(id: 'different_id');

        expect(
          () => userRepository.create(duplicateUser),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('should create multiple users in batch', () async {
        final users = [
          testUser,
          testUser.copyWith(id: 'user_2', email: 'user2@example.com'),
          testUser.copyWith(id: 'user_3', email: 'user3@example.com'),
        ];

        final createdUsers = await userRepository.createBatch(users);
        
        expect(createdUsers.length, equals(3));
        
        // Verify all users were created
        for (final user in users) {
          final foundUser = await userRepository.findById(user.id);
          expect(foundUser, isNotNull);
        }
      });
    });

    group('Read Operations', () {
      setUp(() async {
        await userRepository.create(testUser);
      });

      test('should find user by id', () async {
        final foundUser = await userRepository.findById(testUser.id);
        
        expect(foundUser, isNotNull);
        expect(foundUser!.id, equals(testUser.id));
        expect(foundUser.email, equals(testUser.email));
        expect(foundUser.displayName, equals(testUser.displayName));
      });

      test('should return null when user not found', () async {
        final foundUser = await userRepository.findById('non_existent_id');
        expect(foundUser, isNull);
      });

      test('should find user by email', () async {
        final foundUser = await userRepository.findByEmail(testUser.email);
        
        expect(foundUser, isNotNull);
        expect(foundUser!.email, equals(testUser.email));
      });

      test('should return null when email not found', () async {
        final foundUser = await userRepository.findByEmail('nonexistent@example.com');
        expect(foundUser, isNull);
      });

      test('should find all users', () async {
        // Create additional users
        await userRepository.create(
          testUser.copyWith(id: 'user_2', email: 'user2@example.com')
        );
        await userRepository.create(
          testUser.copyWith(id: 'user_3', email: 'user3@example.com')
        );

        final allUsers = await userRepository.findAll();
        
        expect(allUsers.length, equals(3));
        expect(allUsers.map((u) => u.id), contains(testUser.id));
      });

      test('should find active users only', () async {
        // Create inactive user
        await userRepository.create(
          testUser.copyWith(id: 'inactive_user', email: 'inactive@example.com', isActive: false)
        );

        final activeUsers = await userRepository.findActiveUsers();
        
        expect(activeUsers.length, equals(1));
        expect(activeUsers.first.isActive, isTrue);
      });

      test('should check if user exists', () async {
        final exists = await userRepository.exists(testUser.id);
        expect(exists, isTrue);

        final notExists = await userRepository.exists('non_existent_id');
        expect(notExists, isFalse);
      });

      test('should count users', () async {
        final count = await userRepository.count();
        expect(count, equals(1));

        await userRepository.create(
          testUser.copyWith(id: 'user_2', email: 'user2@example.com')
        );

        final newCount = await userRepository.count();
        expect(newCount, equals(2));
      });

      test('should find users with pagination', () async {
        // Create multiple users
        for (int i = 2; i <= 10; i++) {
          await userRepository.create(
            testUser.copyWith(id: 'user_$i', email: 'user$i@example.com')
          );
        }

        final firstPage = await userRepository.findWithPagination(offset: 0, limit: 5);
        expect(firstPage.length, equals(5));

        final secondPage = await userRepository.findWithPagination(offset: 5, limit: 5);
        expect(secondPage.length, equals(5));

        // Ensure no overlap
        final firstPageIds = firstPage.map((u) => u.id).toSet();
        final secondPageIds = secondPage.map((u) => u.id).toSet();
        expect(firstPageIds.intersection(secondPageIds), isEmpty);
      });
    });

    group('Update Operations', () {
      setUp(() async {
        await userRepository.create(testUser);
      });

      test('should update user successfully', () async {
        final updatedUser = testUser.copyWith(
          displayName: 'Updated Name',
          preferredLanguage: 'ja',
          lastSyncAt: DateTime.now(),
        );

        final result = await userRepository.update(updatedUser);
        
        expect(result.displayName, equals('Updated Name'));
        expect(result.preferredLanguage, equals('ja'));
        
        // Verify update in database
        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser!.displayName, equals('Updated Name'));
        expect(foundUser.preferredLanguage, equals('ja'));
      });

      test('should throw exception when updating non-existent user', () async {
        final nonExistentUser = testUser.copyWith(id: 'non_existent');

        expect(
          () => userRepository.update(nonExistentUser),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should update last sync time', () async {
        final syncTime = DateTime.now();
        
        await userRepository.updateLastSyncTime(testUser.id, syncTime);
        
        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser!.lastSyncAt, isNotNull);
        // Allow for small time differences due to millisecond precision
        expect(
          foundUser.lastSyncAt!.difference(syncTime).inMilliseconds.abs(),
          lessThan(1000),
        );
      });

      test('should update preferred language', () async {
        await userRepository.updatePreferredLanguage(testUser.id, 'ja');
        
        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser!.preferredLanguage, equals('ja'));
      });

      test('should throw exception for unsupported language', () async {
        expect(
          () => userRepository.updatePreferredLanguage(testUser.id, 'fr'),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should deactivate user', () async {
        await userRepository.deactivateUser(testUser.id);
        
        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser!.isActive, isFalse);
      });

      test('should reactivate user', () async {
        await userRepository.deactivateUser(testUser.id);
        await userRepository.reactivateUser(testUser.id);
        
        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser!.isActive, isTrue);
      });

      test('should update multiple users in batch', () async {
        // Create additional users
        final user2 = testUser.copyWith(id: 'user_2', email: 'user2@example.com');
        await userRepository.create(user2);

        final updatedUsers = [
          testUser.copyWith(displayName: 'Updated User 1'),
          user2.copyWith(displayName: 'Updated User 2'),
        ];

        await userRepository.updateBatch(updatedUsers);

        // Verify updates
        final foundUser1 = await userRepository.findById(testUser.id);
        final foundUser2 = await userRepository.findById(user2.id);
        
        expect(foundUser1!.displayName, equals('Updated User 1'));
        expect(foundUser2!.displayName, equals('Updated User 2'));
      });
    });

    group('Delete Operations', () {
      setUp(() async {
        await userRepository.create(testUser);
      });

      test('should delete user by id', () async {
        final deleted = await userRepository.deleteById(testUser.id);
        expect(deleted, isTrue);

        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser, isNull);
      });

      test('should return false when deleting non-existent user', () async {
        final deleted = await userRepository.deleteById('non_existent_id');
        expect(deleted, isFalse);
      });

      test('should delete user entity', () async {
        final deleted = await userRepository.delete(testUser);
        expect(deleted, isTrue);

        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser, isNull);
      });

      test('should delete multiple users in batch', () async {
        // Create additional users
        final user2 = testUser.copyWith(id: 'user_2', email: 'user2@example.com');
        final user3 = testUser.copyWith(id: 'user_3', email: 'user3@example.com');
        await userRepository.create(user2);
        await userRepository.create(user3);

        final deletedCount = await userRepository.deleteBatch([testUser.id, user2.id]);
        expect(deletedCount, equals(2));

        // Verify deletions
        expect(await userRepository.findById(testUser.id), isNull);
        expect(await userRepository.findById(user2.id), isNull);
        expect(await userRepository.findById(user3.id), isNotNull);
      });

      test('should clear all users', () async {
        // Create additional users
        await userRepository.create(
          testUser.copyWith(id: 'user_2', email: 'user2@example.com')
        );

        final deletedCount = await userRepository.clear();
        expect(deletedCount, equals(2));

        final count = await userRepository.count();
        expect(count, equals(0));
      });
    });

    group('Error Handling', () {
      test('should handle database connection errors gracefully', () async {
        // Close database to simulate connection error
        await databaseHelper.close();

        expect(
          () => userRepository.findById(testUser.id),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should provide meaningful error messages', () async {
        try {
          await userRepository.create(User(
            id: '',
            email: 'invalid',
            displayName: '',
            createdAt: DateTime.now(),
          ));
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;
          expect(exception.message, contains('Invalid user data'));
          expect(exception.operation, equals('create user'));
        }
      });
    });

    group('Data Validation', () {
      test('should validate user data before operations', () async {
        final invalidUser = User(
          id: 'test',
          email: 'not-an-email',
          displayName: 'x' * 100, // Too long
          createdAt: DateTime.now(),
        );

        expect(
          () => userRepository.create(invalidUser),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should handle special characters in user data', () async {
        final userWithSpecialChars = testUser.copyWith(
          displayName: 'Test User 🎯 with émojis and àccénts',
          email: 'test+special@example.com',
        );

        final createdUser = await userRepository.create(userWithSpecialChars);
        expect(createdUser.displayName, equals(userWithSpecialChars.displayName));

        final foundUser = await userRepository.findById(userWithSpecialChars.id);
        expect(foundUser!.displayName, equals(userWithSpecialChars.displayName));
      });
    });
  });
}