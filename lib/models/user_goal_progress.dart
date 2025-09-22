class UserGoalProgress {
  final String goalId;
  final int progressValue;
  final String status;

  UserGoalProgress({
    required this.goalId,
    required this.progressValue,
    required this.status,
  });

  factory UserGoalProgress.fromMap(String id, Map<String, dynamic> data) {
    return UserGoalProgress(
      goalId: id,
      progressValue: data['progressValue'] ?? 0,
      status: data['status'] ?? 'in-progress',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'progressValue': progressValue,
      'status': status,
    };
  }
}
