import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network.dart';
import '../data/models.dart';

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier();
});

class FeedState {
  final bool isLoading;
  final List<Task> tasks;
  final String? error;
  final String? swipeError;

  FeedState({this.isLoading = false, this.tasks = const [], this.error, this.swipeError});

  FeedState copyWith({bool? isLoading, List<Task>? tasks, String? error, String? swipeError}) {
    return FeedState(
      isLoading: isLoading ?? this.isLoading,
      tasks: tasks ?? this.tasks,
      error: error,
      swipeError: swipeError,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier() : super(FeedState()) {
    fetchFeed();
  }

  Future<void> fetchFeed() async {
    state = state.copyWith(isLoading: true, error: null, swipeError: null);
    try {
      final response = await apiClient.dio.get('/tasks/feed');
      final List<Task> tasks = (response.data as List).map((t) => Task.fromJson(t)).toList();
      state = state.copyWith(isLoading: false, tasks: tasks);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Не удалось загрузить ленту');
    }
  }

  Future<void> swipeLeft(int taskId) async {
    try {
      await apiClient.dio.post('/tasks/$taskId/swipe_left');
      state = state.copyWith(tasks: state.tasks.where((t) => t.id != taskId).toList());
    } catch (e) {
      await fetchFeed();
    }
  }

  Future<int?> swipeRight(int taskId) async {
    try {
      final response = await apiClient.dio.post('/tasks/$taskId/swipe_right');
      state = state.copyWith(tasks: state.tasks.where((t) => t.id != taskId).toList());
      return response.data['id'] as int;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Не удалось взять задачу';
      state = state.copyWith(swipeError: msg.toString());
      await fetchFeed();
      return null;
    } catch (e) {
      state = state.copyWith(swipeError: 'Ошибка');
      await fetchFeed();
      return null;
    }
  }

  void clearSwipeError() {
    state = state.copyWith(swipeError: null);
  }
}
