import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network.dart';
import '../data/models.dart';

final achievementsProvider = StateNotifierProvider<AchievementsNotifier, AchievementsState>((ref) {
  return AchievementsNotifier();
});

class AchievementsState {
  final bool isLoading;
  final List<Achievement> achievements;

  AchievementsState({this.isLoading = false, this.achievements = const []});

  AchievementsState copyWith({bool? isLoading, List<Achievement>? achievements}) {
    return AchievementsState(
      isLoading: isLoading ?? this.isLoading,
      achievements: achievements ?? this.achievements,
    );
  }
}

class AchievementsNotifier extends StateNotifier<AchievementsState> {
  AchievementsNotifier() : super(AchievementsState()) {
    fetchAchievements();
  }

  Future<void> fetchAchievements() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await apiClient.dio.get('/achievements/');
      final list = (response.data as List).map((a) => Achievement.fromJson(a)).toList();
      state = state.copyWith(isLoading: false, achievements: list);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}
