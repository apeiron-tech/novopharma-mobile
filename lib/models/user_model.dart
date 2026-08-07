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
  final double points;
  final double pendingPluxeePoints;
  final double totalPointsValidated;
  final double pointsInvalid;
  final String pharmacyCategory;
  final String? avatarUrl;
  final String? phone;
  final String? position;
  final String? city;
  final String? pointOfSale;
  final String role;
  final bool birthdayNotif;

  static const String defaultAvatarUrl =
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face';

  // Calculated properties
  double get availablePoints => points - pendingPluxeePoints;
  double get totalPointsCumules => totalPointsValidated + pointsInvalid;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.status = UserStatus.unknown,
    required this.pharmacyId,
    this.pharmacy,
    this.pharmacyCategory = 'Pharmacie',
    this.dateOfBirth,
    this.points = 0,
    this.pendingPluxeePoints = 0,
    this.totalPointsValidated = 0,
    this.pointsInvalid = 0,
    this.avatarUrl,
    this.phone,
    this.position,
    this.city,
    this.pointOfSale,
    this.role = '',
    this.birthdayNotif = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle potential data mismatch from Backoffice
    dynamic positionData = data['position'];
    String? positionStr;
    String? statusStr = data['status'];

    if (positionData is Map) {
      // Backoffice structure: position is a Map, and status might be nested inside
      if (statusStr == null && positionData['status'] is String) {
        statusStr = positionData['status'];
      }
      // If position is a map (likely geolocation), we can't use it as a String position title
      positionStr = null;
    } else if (positionData is String) {
      positionStr = positionData;
    }

    String pCat = data['pharmacyCategory'] as String? ?? '';
    if (pCat.trim().isEmpty) {
      pCat = 'Pharmacie';
    }

    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      status: _statusFromString(statusStr),
      pharmacyId: data['pharmacyId'] ?? '',
      pharmacy: data['pharmacy'],
      pharmacyCategory: pCat,
      dateOfBirth: _parseDate(data['dateOfBirth']),
      points: (data['points'] as num?)?.toDouble() ?? 0.0,
      pendingPluxeePoints:
          (data['pendingPluxeePoints'] as num?)?.toDouble() ?? 0.0,
      totalPointsValidated:
          (data['totalPointsValidated'] as num?)?.toDouble() ?? (data['points'] as num?)?.toDouble() ?? 0.0,
      pointsInvalid: (data['pointsInvalid'] as num?)?.toDouble() ?? 0.0,
      avatarUrl: data['avatarUrl'],
      phone: data['phone'],
      position: positionStr,
      city: data['city'],
      pointOfSale: data['pointOfSale'],
      role: data['role'] ?? '',
      birthdayNotif: data['birthdayNotif'] as bool? ?? true,
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

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.tryParse(date);
    return null;
  }
}
