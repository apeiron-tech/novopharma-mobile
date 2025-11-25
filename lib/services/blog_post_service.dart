import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/blog_post.dart';

class BlogPostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'blogPosts';

  /// Get real-time stream of published formation blog posts
  Stream<List<BlogPost>> getFormationsStream() {
    try {
      return _firestore
          .collection(_collection)
          .where('type', isEqualTo: 'formation')
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs
                .map((doc) => BlogPost.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('Error setting up formations stream: $e');
      return Stream.value([]);
    }
  }

  /// Get all published blog posts (for Actualités section if needed)
  Stream<List<BlogPost>> getAllPublishedPostsStream() {
    try {
      return _firestore
          .collection(_collection)
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs
                .map((doc) => BlogPost.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('Error setting up blog posts stream: $e');
      return Stream.value([]);
    }
  }

  /// Get blog posts by type
  Stream<List<BlogPost>> getPostsByTypeStream(String type) {
    try {
      return _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs
                .map((doc) => BlogPost.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('Error setting up posts stream for type $type: $e');
      return Stream.value([]);
    }
  }

  /// Get a single blog post by ID
  Future<BlogPost?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (doc.exists) {
        return BlogPost.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching blog post by ID: $e');
      return null;
    }
  }

  /// Get blog post by slug
  Future<BlogPost?> getPostBySlug(String slug) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('slug', isEqualTo: slug)
          .where('isPublished', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return BlogPost.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error fetching blog post by slug: $e');
      return null;
    }
  }

  /// Get posts by tag
  Stream<List<BlogPost>> getPostsByTagStream(String tag) {
    try {
      return _firestore
          .collection(_collection)
          .where('tags', arrayContains: tag)
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs
                .map((doc) => BlogPost.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('Error setting up posts stream for tag $tag: $e');
      return Stream.value([]);
    }
  }

  /// Get active formations (those within start/end date range if specified)
  Stream<List<BlogPost>> getActiveFormationsStream() {
    try {
      return _firestore
          .collection(_collection)
          .where('type', isEqualTo: 'formation')
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs
                .map((doc) => BlogPost.fromFirestore(doc))
                .where(
                  (post) => post.isActive,
                ) // Filter active posts on client side
                .toList();
          });
    } catch (e) {
      print('Error setting up active formations stream: $e');
      return Stream.value([]);
    }
  }

  /// Search formations by title or content
  Future<List<BlogPost>> searchFormations(String searchQuery) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a simple title search. For advanced search, consider using Algolia or similar
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: 'formation')
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => BlogPost.fromFirestore(doc))
          .where(
            (post) =>
                post.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                post.content.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                post.tags.any(
                  (tag) =>
                      tag.toLowerCase().contains(searchQuery.toLowerCase()),
                ),
          )
          .toList();
    } catch (e) {
      print('Error searching formations: $e');
      return [];
    }
  }
}
