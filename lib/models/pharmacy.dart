import 'package:cloud_firestore/cloud_firestore.dart';

class PointOfSale {
  final String name;
  final String city;

  PointOfSale({
    required this.name,
    required this.city,
  });

  factory PointOfSale.fromMap(Map<String, dynamic> map) {
    return PointOfSale(
      name: map['name'] ?? '',
      city: map['city'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city': city,
    };
  }
}

class Pharmacy {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String postalCode;
  final String zone;
  final String clientCategory;
  final GeoPoint location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasPointsOfSale;
  final List<PointOfSale> pointsOfSale;

  Pharmacy({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.zone,
    required this.clientCategory,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    this.hasPointsOfSale = false,
    this.pointsOfSale = const [],
  });

  factory Pharmacy.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<PointOfSale> posList = [];
    if (data['pointsOfSale'] != null && data['pointsOfSale'] is List) {
      posList = (data['pointsOfSale'] as List)
          .where((item) => item is Map)
          .map((item) => PointOfSale.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return Pharmacy(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      postalCode: data['postalCode'] ?? '',
      zone: data['zone'] ?? '',
      clientCategory: data['clientCategory'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasPointsOfSale: data['hasPointsOfSale'] == true,
      pointsOfSale: posList,
    );
  }
}
