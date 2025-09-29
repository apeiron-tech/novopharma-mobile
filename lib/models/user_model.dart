import 'package:cloud_firestore/cloud_firestore.dart';

enum UserStatus { pending, active, disabled, unknown }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserStatus status;
  final String pharmacyId;
  final String? pharmacy;
  final DateTime? dateOfBirth;
  final int points;
  final String? avatarUrl;
  final String? phone;

  static const String defaultAvatarUrl = 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face';

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.status = UserStatus.unknown,
    required this.pharmacyId,
    this.pharmacy,
    this.dateOfBirth,
    this.points = 0,
    this.avatarUrl,
    this.phone,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      status: _statusFromString(data['status']),
      pharmacyId: data['pharmacyId'],
      pharmacy: data['pharmacy'],
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      points: data['points'] ?? 0,
      avatarUrl: data['avatarUrl'],
      phone: data['phone'],
    );
  }

  static UserStatus _statusFromString(String? status) {
    switch (status) {
      case 'active':
        return UserStatus.active;
      case 'pending':
        return UserStatus.pending;
      case 'disabled':
        return UserStatus.disabled;
      default:
        return UserStatus.unknown;
    }
  }
}
