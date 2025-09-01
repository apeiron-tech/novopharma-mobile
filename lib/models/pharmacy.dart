import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory Pharmacy.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
    );
  }
}
