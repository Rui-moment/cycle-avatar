import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String displayName,
    required DateTime createdAt,
    DateTime? lastSyncAt,
    @Default('en') String preferredLanguage,
    @Default(true) bool isActive,
  }) = _User;

  const User._();

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Validates user data
  String? validate() {
    if (id.isEmpty) return 'User ID cannot be empty';
    if (email.isEmpty) return 'Email cannot be empty';
    if (!_isValidEmail(email)) return 'Invalid email format';
    if (displayName.isEmpty) return 'Display name cannot be empty';
    if (displayName.length > 50) return 'Display name too long (max 50 characters)';
    if (!['en', 'ja'].contains(preferredLanguage)) {
      return 'Unsupported language: $preferredLanguage';
    }
    return null;
  }

  /// Checks if the user data is valid
  bool get isValid => validate() == null;

  /// Simple email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  /// Gets localized display name or falls back to email
  String getDisplayName() {
    return displayName.isNotEmpty ? displayName : email.split('@').first;
  }
}