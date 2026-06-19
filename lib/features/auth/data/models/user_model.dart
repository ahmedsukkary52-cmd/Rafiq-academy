import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.name,
    required super.role,
    required super.phone,
    super.email,
    super.profileImageUrl,
    required super.isActive,
    required super.createdAt,
  });

  /// من Firestore document لـ UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role,
      'phone': phone,
      if (email != null) 'email': email,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      name: entity.name,
      role: entity.role,
      phone: entity.phone,
      email: entity.email,
      profileImageUrl: entity.profileImageUrl,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
