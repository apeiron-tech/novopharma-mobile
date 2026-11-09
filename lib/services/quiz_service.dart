import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/quiz.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'quizzes';

  Future<List<Quiz>> getAllQuizzes() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      final List<Quiz> quizzes = querySnapshot.docs
          .map((doc) => Quiz.fromFirestore(doc))
          .toList();
      return quizzes;
    } catch (e) {
      print('Error fetching quizzes: $e');
      return [];
    }
  }

  Future<Quiz?> getWeeklyQuiz() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: 'weekly')
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return Quiz.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error fetching weekly quiz: $e');
      return null;
    }
  }

  Future<Quiz?> getQuizById(String quizId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(quizId).get();
      if (doc.exists) {
        return Quiz.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching quiz by id: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLastUserAttempt(
    String userId,
    String quizId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quizAttempts')
          .where('quizId', isEqualTo: quizId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        data['id'] = querySnapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting last user attempt: $e');
      return null;
    }
  }

  Future<void> submitQuiz(
    String userId,
    String quizId,
    int score,
    int pointsEarned, {
    Map<int, List<int>>? selectedAnswers,
  }) async {
    try {
      final Map<String, dynamic> attemptData = {
        'quizId': quizId,
        'score': score,
        'pointsEarned': pointsEarned,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (selectedAnswers != null) {
        final Map<String, dynamic> formattedAnswers = {};
        selectedAnswers.forEach((key, value) {
          formattedAnswers[key.toString()] = value;
        });
        attemptData['selectedAnswers'] = formattedAnswers;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('quizAttempts')
          .add(attemptData);

      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(pointsEarned),
      });
    } catch (e) {
      print('Error submitting quiz: $e');
      rethrow;
    }
  }

  Future<int> getUserAttemptCount(String userId, String quizId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quizAttempts')
          .where('quizId', isEqualTo: quizId)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting user attempt count: $e');
      return 0; // Return 0 on error to prevent blocking the quiz
    }
  }
}
