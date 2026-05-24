class User {
  final int id;
  final String email;
  final String name;
  final String role;
  final int karmaBalance;
  final int level;
  final String? city;
  final List<String> skills;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.karmaBalance,
    required this.level,
    this.city,
    this.skills = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'volunteer',
      karmaBalance: json['karma_balance'] ?? 0,
      level: json['level'] ?? 1,
      city: json['city'],
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
    );
  }
}

class Task {
  final int id;
  final int foundationId;
  final String title;
  final String description;
  final int durationMinutes;
  final int karmaReward;
  final String status;
  final String? city;
  final bool isPhysical;
  final List<String> skillsRequired;

  Task({
    required this.id,
    required this.foundationId,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.karmaReward,
    required this.status,
    this.city,
    this.isPhysical = false,
    this.skillsRequired = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      foundationId: json['foundation_id'] as int,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      karmaReward: json['karma_reward'] ?? 0,
      status: json['status'] ?? 'active',
      city: json['city'],
      isPhysical: json['is_physical'] ?? false,
      skillsRequired: json['skills_required'] != null
          ? List<String>.from(json['skills_required'])
          : [],
    );
  }
}

class TaskAssignment {
  final int id;
  final int taskId;
  final int volunteerId;
  final String status;
  final Task? task;
  final String? resultText;
  final String? foundationComment;

  TaskAssignment({
    required this.id,
    required this.taskId,
    required this.volunteerId,
    required this.status,
    this.task,
    this.resultText,
    this.foundationComment,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      volunteerId: json['volunteer_id'] as int,
      status: json['status'] ?? '',
      task: json['task'] != null ? Task.fromJson(json['task']) : null,
      resultText: json['result_text'],
      foundationComment: json['foundation_comment'],
    );
  }
}

class Achievement {
  final int id;
  final String title;
  final String description;
  final int requiredKarma;
  final String iconCode;
  final bool unlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredKarma,
    required this.iconCode,
    this.unlocked = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as int,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      requiredKarma: json['required_karma'] ?? 0,
      iconCode: json['icon_code'] ?? 'star',
      unlocked: json['unlocked'] ?? false,
    );
  }
}
