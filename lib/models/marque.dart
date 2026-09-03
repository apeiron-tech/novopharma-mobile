import 'package:cloud_firestore/cloud_firestore.dart';

class MarqueContact {
  final String responsibleName;
  final String phoneNumber;
  final String? secteur;

  MarqueContact({
    required this.responsibleName,
    required this.phoneNumber,
    this.secteur,
  });

  factory MarqueContact.fromMap(Map<String, dynamic> map) {
    return MarqueContact(
      responsibleName: map['responsibleName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      secteur: map['secteur'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'responsibleName': responsibleName,
      'phoneNumber': phoneNumber,
      if (secteur != null) 'secteur': secteur,
    };
  }
}

class MarqueModel {
  final String id;
  final String marqueName;
  final List<String> categories;
  final String? logo;
  final List<MarqueContact> contactList;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MarqueModel({
    required this.id,
    required this.marqueName,
    required this.categories,
    this.logo,
    required this.contactList,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory MarqueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawContacts = data['contactList'] as List<dynamic>? ?? [];
    final parsedContacts = rawContacts
        .map((c) => MarqueContact.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList();

    return MarqueModel(
      id: doc.id,
      marqueName: data['marqueName'] as String? ?? '',
      categories: List<String>.from(data['categories'] ?? []),
      logo: data['logo'] as String?,
      contactList: parsedContacts,
      status: data['status'] as String? ?? 'active',
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }
}
