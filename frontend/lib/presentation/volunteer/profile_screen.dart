import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/achievements_provider.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).refreshUser();
      ref.read(achievementsProvider.notifier).fetchAchievements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final achievementsState = ref.watch(achievementsProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final karmaToNext = ((user.level) * 100) - user.karmaBalance;
    final progress = (user.karmaBalance % 100) / 100.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildProfileHeader(context, user, progress, karmaToNext),
              const SizedBox(height: 28),
              _buildStatsRow(context, user),
              const SizedBox(height: 28),
              _buildAchievementsSection(context, achievementsState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User user, double progress, int karmaToNext) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Уровень ${user.level}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              const SizedBox(width: 8),
              Text('→ ${karmaToNext > 0 ? karmaToNext : 0} кармы до след.', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, User user) {
    return Row(
      children: [
        Expanded(child: _statCard(context, '${user.level}', 'Уровень', Icons.military_tech_rounded, AppTheme.warningColor)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(context, '${user.karmaBalance}', 'Карма', Icons.star_rounded, AppTheme.primaryColor)),
      ],
    );
  }

  Widget _statCard(BuildContext context, String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context, AchievementsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Достижения', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        if (state.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (state.achievements.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('Пока нет достижений', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          )
        else
          ...state.achievements.map((a) => _achievementTile(context, a)),
      ],
    );
  }

  Widget _achievementTile(BuildContext context, Achievement achievement) {
    final iconMap = {
      'star': Icons.star_rounded,
      'fire': Icons.local_fire_department_rounded,
      'heart': Icons.favorite_rounded,
      'trophy': Icons.emoji_events_rounded,
      'rocket': Icons.rocket_launch_rounded,
      'lightning': Icons.flash_on_rounded,
    };
    final icon = iconMap[achievement.iconCode] ?? Icons.star_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: achievement.unlocked
            ? Border.all(color: AppTheme.successColor.withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: achievement.unlocked
                  ? AppTheme.warningColor.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: achievement.unlocked ? AppTheme.warningColor : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: achievement.unlocked ? AppTheme.textPrimary : Colors.grey,
                  ),
                ),
                Text(
                  achievement.description,
                  style: TextStyle(fontSize: 12, color: achievement.unlocked ? AppTheme.textSecondary : Colors.grey[400]),
                ),
              ],
            ),
          ),
          if (achievement.unlocked)
            const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 22)
          else
            Text(
              '${achievement.requiredKarma} кармы',
              style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}
