import 'package:cloud_firestore/cloud_firestore.dart';

class Quiz {
  final String id;
  final String title;
  final String type;
  final bool active;
  final int attemptLimit;
  final int points;
  final int quizTimeLimitSeconds;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QuizQuestion> questions;
  final int minCorrectAnswersToWin;

  Quiz({
    required this.id,
    required this.title,
    this.type = "regular",
    required this.active,
    required this.attemptLimit,
    required this.points,
    required this.quizTimeLimitSeconds,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
    required this.questions,
    this.minCorrectAnswersToWin = 0,
  });

  int get effectiveMinCorrectAnswers =>
      (minCorrectAnswersToWin <= 0) ? questions.length : minCorrectAnswersToWin;

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    var questionsData = data['questions'] as List<dynamic>? ?? [];
    return Quiz(
      id: doc.id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'regular',
      active: data['active'] ?? false,
      attemptLimit: data['attemptLimit'] ?? 0,
      points: data['points'] ?? 0,
      quizTimeLimitSeconds: data['quizTimeLimitSeconds'] ?? 0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      questions: questionsData.map((q) => QuizQuestion.fromMap(q)).toList(),
      minCorrectAnswersToWin: data['minCorrectAnswersToWin'] is int
          ? data['minCorrectAnswersToWin']
          : (int.tryParse(data['minCorrectAnswersToWin']?.toString() ?? '') ?? 0),
    );
  }
}

class QuizQuestion {
  final String text;
  final List<String> options;
  final List<int> correctAnswers;
  final String explanation;
  final bool multipleAnswersAllowed;
  final int timeLimitSeconds;

  QuizQuestion({
    required this.text,
    required this.options,
    required this.correctAnswers,
    required this.explanation,
    required this.multipleAnswersAllowed,
    required this.timeLimitSeconds,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> data) {
    return QuizQuestion(
      text: data['text'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswers: List<int>.from(data['correctAnswers'] ?? []),
      explanation: data['explanation'] ?? '',
      multipleAnswersAllowed: data['multipleAnswersAllowed'] ?? false,
      timeLimitSeconds: data['timeLimitInSeconds'] ?? 30,
    );
  }
}
