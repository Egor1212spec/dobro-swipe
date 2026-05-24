import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref, user),
            const SizedBox(height: 8),
            _buildStats(context, dashboardState),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Ваши задачи', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildTasksList(context, dashboardState)),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/foundation/create_task'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: const Text('Новая задача', style: TextStyle(fontWeight: FontWeight.w600)),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, dynamic user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.name ?? 'Фонд', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text('Панель управления', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
            ),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, DashboardState state) {
    int active = 0, underReview = 0, completed = 0;
    for (var task in state.dashboardTasks) {
      if (task['status'] == 'completed') {
        completed++;
      } else {
        active++;
      }
      for (var a in (task['assignments'] ?? [])) {
        if (a['status'] == 'under_review') underReview++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _miniStat(context, '$active', 'Активных', AppTheme.primaryColor)),
          const SizedBox(width: 10),
          Expanded(child: _miniStat(context, '$underReview', 'На проверке', AppTheme.warningColor)),
          const SizedBox(width: 10),
          Expanded(child: _miniStat(context, '$completed', 'Завершено', AppTheme.successColor)),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTasksList(BuildContext context, DashboardState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.dashboardTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Пока нет задач', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: state.dashboardTasks.length,
      itemBuilder: (context, index) {
        final task = state.dashboardTasks[index];
        return _buildTaskCard(context, task);
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, dynamic task) {
    int underReview = 0;
    int inProgress = 0;
    for (var a in (task['assignments'] ?? [])) {
      if (a['status'] == 'under_review') underReview++;
      if (a['status'] == 'in_progress') inProgress++;
    }

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (underReview > 0) {
      statusText = '$underReview на проверке';
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.rate_review_outlined;
    } else if (inProgress > 0) {
      statusText = '$inProgress в работе';
      statusColor = AppTheme.primaryColor;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (task['status'] == 'completed') {
      statusText = 'Завершено';
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle_outline;
    } else {
      statusText = 'Ожидает';
      statusColor = AppTheme.textSecondary;
      statusIcon = Icons.access_time_rounded;
    }

    return GestureDetector(
      onTap: () => context.push('/foundation/review', extra: task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(statusText, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
