import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/quiz.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'quizzes';

  Future<List<Quiz>> getAvailableQuizzes() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('active', isEqualTo: true)
          .get();
      final List<Quiz> quizzes =
          querySnapshot.docs.map((doc) => Quiz.fromFirestore(doc)).toList();
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

  Future<void> submitQuiz(
      String userId, String quizId, int score, int pointsEarned) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('quizAttempts')
          .add({
        'quizId': quizId,
        'score': score,
        'pointsEarned': pointsEarned,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(pointsEarned),
      });
    } catch (e) {
      print('Error submitting quiz: $e');
      rethrow;
    }
  }
}
