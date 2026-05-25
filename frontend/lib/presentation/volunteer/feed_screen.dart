import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:go_router/go_router.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/models.dart';
import '../../core/theme.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  AppinioSwiperController controller = AppinioSwiperController();
  bool _isSwiping = false;
  int? _handledIndex;
  int _swiperEpoch = 0;
  int _swipedCount = 0;

  void _swipeLeft() {
    if (_isSwiping) return;
    _isSwiping = true;
    controller.swipeLeft();
  }

  void _swipeRight() {
    if (_isSwiping) return;
    _isSwiping = true;
    controller.swipeRight();
  }

  Future<void> _maybeRefreshAfterSwipe(int totalCards) async {
    _swipedCount += 1;
    if (_swipedCount >= totalCards) {
      await ref.read(feedProvider.notifier).fetchFeed();
      if (!mounted) return;
      setState(() {
        controller = AppinioSwiperController();
        _swiperEpoch += 1;
        _swipedCount = 0;
        _handledIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final user = ref.watch(authProvider).user;

    ref.listen<FeedState>(feedProvider, (prev, next) {
      if (next.swipeError != null && next.swipeError != prev?.swipeError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.swipeError!),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        ref.read(feedProvider.notifier).clearSwipeError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user),
            Expanded(child: _buildBody(feedState)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Привет, ${user?.name.split(' ').first ?? ''}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Найди задачу по душе',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(FeedState feedState) {
    if (feedState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feedState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Не удалось загрузить ленту', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(feedState.error!, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.read(feedProvider.notifier).fetchFeed(),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (feedState.tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.check_circle_outline, size: 40, color: AppTheme.successColor),
              ),
              const SizedBox(height: 20),
              Text('Все задачи просмотрены!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Загляните позже — фонды публикуют\nновые задачи каждый день',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppinioSwiper(
              key: ValueKey(_swiperEpoch),
              controller: controller,
              cardCount: feedState.tasks.length,
              onSwipeBegin: (previousIndex, targetIndex, activity) {
                _isSwiping = true;
              },
              onSwipeEnd: (previousIndex, targetIndex, activity) async {
                if (_handledIndex == previousIndex) return;
                _handledIndex = previousIndex;
                if (previousIndex < 0 || previousIndex >= feedState.tasks.length) {
                  _isSwiping = false;
                  return;
                }
                final task = feedState.tasks[previousIndex];
                final totalCards = feedState.tasks.length;
                try {
                  if (activity.direction == AxisDirection.right) {
                    if (!mounted) return;
                    await context.push('/volunteer/active', extra: {'task': task});
                  } else if (activity.direction == AxisDirection.left) {
                    await ref.read(feedProvider.notifier).swipeLeft(task.id);
                  }
                  await _maybeRefreshAfterSwipe(totalCards);
                } finally {
                  if (mounted) {
                    _isSwiping = false;
                    _handledIndex = null;
                  }
                }
              },
              cardBuilder: (BuildContext context, int index) {
                return _buildCard(feedState.tasks[index]);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSwipeButtons(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSwipeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          icon: Icons.close_rounded,
          color: AppTheme.accentColor,
          onTap: _swipeLeft,
          size: 56,
        ),
        const SizedBox(width: 32),
        _buildActionButton(
          icon: Icons.favorite_rounded,
          color: AppTheme.successColor,
          onTap: _swipeRight,
          size: 64,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }

  Widget _buildCard(Task task) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCardHero(task),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(task.imageUrl != null ? 0.45 : 0.0),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '+${task.karmaReward}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                if (task.tags.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: task.tags.take(4).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      task.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTag(Icons.timer_outlined, '${task.durationMinutes} мин'),
                      const SizedBox(width: 8),
                      if (task.city != null) _buildTag(Icons.location_on_outlined, task.city!),
                    ],
                  ),
                  if (task.skillsRequired.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: task.skillsRequired.take(3).map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryDark.withOpacity(0.2)),
                        ),
                        child: Text(s, style: const TextStyle(fontSize: 11, color: AppTheme.primaryDark, fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHero(Task task) {
    if (task.imageUrl != null && task.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: task.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppTheme.surfaceLight),
        errorWidget: (_, __, ___) => _buildPlaceholderHero(task),
      );
    }
    return _buildPlaceholderHero(task);
  }

  Widget _buildPlaceholderHero(Task task) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.8),
            AppTheme.primaryDark.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          task.isPhysical ? Icons.place_outlined : Icons.laptop_mac_outlined,
          size: 80,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
