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
      name: map['name']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
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

    // Tolerate non-string values (e.g. postalCode/phone saved as numbers):
    // a type error here used to make the pharmacy "missing", which the
    // product screen reported as "Could not load user profile".
    String str(dynamic v) => (v is String) ? v : (v == null ? '' : v.toString());

    GeoPoint parseLocation(dynamic v) {
      if (v is GeoPoint) return v;
      if (v is Map) {
        final lat = v['latitude'] ?? v['lat'];
        final lng = v['longitude'] ?? v['lng'];
        if (lat is num && lng is num) {
          return GeoPoint(lat.toDouble(), lng.toDouble());
        }
      }
      return const GeoPoint(0, 0);
    }

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return Pharmacy(
      id: doc.id,
      name: str(data['name']),
      email: str(data['email']),
      phone: str(data['phone']),
      address: str(data['address']),
      city: str(data['city']),
      postalCode: str(data['postalCode']),
      zone: str(data['zone']),
      clientCategory: str(data['clientCategory']),
      location: parseLocation(data['location']),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      hasPointsOfSale: data['hasPointsOfSale'] == true,
      pointsOfSale: posList,
    );
  }
}
