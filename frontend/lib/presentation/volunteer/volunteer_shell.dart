import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/my_tasks_provider.dart';
import 'feed_screen.dart';
import 'my_tasks_screen.dart';
import 'profile_screen.dart';

class VolunteerShell extends ConsumerStatefulWidget {
  const VolunteerShell({Key? key}) : super(key: key);

  @override
  ConsumerState<VolunteerShell> createState() => _VolunteerShellState();
}

class _VolunteerShellState extends ConsumerState<VolunteerShell> {
  int _currentIndex = 0;

  final _screens = const [
    FeedScreen(),
    MyTasksScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.explore_rounded, Icons.explore_outlined, 'Лента'),
              _navItem(1, Icons.task_alt_rounded, Icons.task_alt_outlined, 'Мои задачи', onTap: () {
                ref.read(myTasksProvider.notifier).fetchMyTasks();
              }),
              _navItem(2, Icons.person_rounded, Icons.person_outlined, 'Профиль'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon, String label, {VoidCallback? onTap}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        onTap?.call();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
