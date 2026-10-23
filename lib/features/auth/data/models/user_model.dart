import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.name,
    required super.role,
    super.email,
    super.profileImageUrl,
    required super.isActive,
    required super.createdAt,
  });

  /// من Firestore document لـ UserModel
  ///
  /// `users.email` is read only as a transition fallback for legacy profiles;
  /// the signed-in user's email comes from Firebase Auth ([withAuthEmail]).
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      email: data['email'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Personal phone numbers are never stored (academy privacy policy), and
  /// email is private (userPrivate/{uid}), so neither is written here.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// The Firebase Auth email wins; a blank one keeps the legacy fallback.
  UserModel withAuthEmail(String? authEmail) {
    final value = authEmail?.trim() ?? '';
    if (value.isEmpty) return this;
    return UserModel(
      uid: uid,
      name: name,
      role: role,
      email: value,
      profileImageUrl: profileImageUrl,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      name: entity.name,
      role: entity.role,
      email: entity.email,
      profileImageUrl: entity.profileImageUrl,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
