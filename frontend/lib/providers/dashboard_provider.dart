import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network.dart';

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});

class DashboardState {
  final bool isLoading;
  final List<dynamic> dashboardTasks; // raw tasks with assignments from API
  final String? error;

  DashboardState({this.isLoading = false, this.dashboardTasks = const [], this.error});

  DashboardState copyWith({bool? isLoading, List<dynamic>? dashboardTasks, String? error}) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      dashboardTasks: dashboardTasks ?? this.dashboardTasks,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(DashboardState()) {
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.dio.get('/tasks/foundation/dashboard');
      state = state.copyWith(isLoading: false, dashboardTasks: response.data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load dashboard');
    }
  }

  Future<bool> createTask(Map<String, dynamic> taskData) async {
    try {
      await apiClient.dio.post('/tasks/', data: taskData);
      await fetchDashboard();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> reviewAssignment(int assignmentId, bool isApproved, String? comment) async {
    try {
      await apiClient.dio.post('/tasks/assignments/$assignmentId/review', data: {
        'is_approved': isApproved,
        'foundation_comment': comment,
      });
      await fetchDashboard();
      return true;
    } catch (e) {
      return false;
    }
  }
}
