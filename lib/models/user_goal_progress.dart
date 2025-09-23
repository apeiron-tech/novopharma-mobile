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
    final num? progressNum = data['progressValue'] as num?;
    int progressValue = 0;
    if (progressNum != null && progressNum.isFinite) {
      progressValue = progressNum.toInt();
    }

    return UserGoalProgress(
      goalId: id,
      progressValue: progressValue,
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
