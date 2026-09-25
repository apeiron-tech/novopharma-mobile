import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfilePicture(String userId, File imageFile) async {
    try {
      // Create a reference to the location you want to upload to in Firebase Storage
      final ref = _storage.ref().child('profile_pictures').child('$userId.jpg');

      // Upload the file
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Wait for the upload to complete
      final snapshot = await uploadTask.whenComplete(() => {});

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }

  /// Uploads a visit photo to /visits-photos/{visit_id}_{timestamp}.jpg
  Future<Map<String, String>?> uploadVisitPhoto(
    String visitId,
    File imageFile,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'visits-photos/${visitId}_$timestamp.jpg';
      final ref = _storage.ref().child(storagePath);

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return {
        'url': downloadUrl,
        'storagePath': storagePath,
      };
    } catch (e) {
      debugPrint('Error uploading visit photo: $e');
      return null;
    }
  }

  /// Deletes a visit photo from Firebase Storage
  Future<bool> deleteVisitPhoto(String storagePath) async {
    try {
      final normalized = storagePath.startsWith('/')
          ? storagePath.substring(1)
          : storagePath;
      final ref = _storage.ref().child(normalized);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting visit photo from storage: $e');
      return false;
    }
  }
}
