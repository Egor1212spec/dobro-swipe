import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network.dart';
import '../data/models.dart';

final myTasksProvider = StateNotifierProvider<MyTasksNotifier, MyTasksState>((ref) {
  return MyTasksNotifier();
});

class ActiveAssignment {
  final int id;
  final String status;
  final Task task;

  ActiveAssignment({required this.id, required this.status, required this.task});

  factory ActiveAssignment.fromJson(Map<String, dynamic> json) {
    return ActiveAssignment(
      id: json['id'] as int,
      status: json['status'] as String,
      task: Task.fromJson(json['task'] as Map<String, dynamic>),
    );
  }
}

class MyTasksState {
  final bool isLoading;
  final List<ActiveAssignment> assignments;

  MyTasksState({this.isLoading = false, this.assignments = const []});

  MyTasksState copyWith({bool? isLoading, List<ActiveAssignment>? assignments}) {
    return MyTasksState(
      isLoading: isLoading ?? this.isLoading,
      assignments: assignments ?? this.assignments,
    );
  }
}

class MyTasksNotifier extends StateNotifier<MyTasksState> {
  MyTasksNotifier() : super(MyTasksState()) {
    fetchMyTasks();
  }

  Future<void> fetchMyTasks() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await apiClient.dio.get('/tasks/my-assignments');
      final list = (response.data as List)
          .map((e) => ActiveAssignment.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(isLoading: false, assignments: list);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}
