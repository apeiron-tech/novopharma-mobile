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
    // Fields edited from the back office / imports are not always strings
    // (e.g. phone saved as a number). A hard cast here made the whole profile
    // fail to load ("Could not load user profile" on the product screen).
    String? optStr(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return null;
    }

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
      return 0.0;
    }

    dynamic positionData = data['position'];
    String? positionStr;
    String? statusStr = optStr(data['status']);

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

    String pCat = optStr(data['pharmacyCategory']) ?? '';
    if (pCat.trim().isEmpty) {
      pCat = 'Pharmacie';
    }

    return UserModel(
      uid: doc.id,
      name: optStr(data['name']) ?? '',
      email: optStr(data['email']) ?? '',
      status: _statusFromString(statusStr),
      pharmacyId: (optStr(data['pharmacyId']) ?? '').trim(),
      pharmacy: optStr(data['pharmacy']),
      pharmacyCategory: pCat,
      dateOfBirth: _parseDate(data['dateOfBirth']),
      points: toDouble(data['points']),
      pendingPluxeePoints: toDouble(data['pendingPluxeePoints']),
      totalPointsValidated: data['totalPointsValidated'] != null
          ? toDouble(data['totalPointsValidated'])
          : toDouble(data['points']),
      pointsInvalid: toDouble(data['pointsInvalid']),
      avatarUrl: optStr(data['avatarUrl']),
      phone: optStr(data['phone']),
      position: positionStr,
      city: optStr(data['city']),
      pointOfSale: optStr(data['pointOfSale']),
      role: optStr(data['role']) ?? '',
      birthdayNotif: data['birthdayNotif'] is bool ? data['birthdayNotif'] : true,
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
