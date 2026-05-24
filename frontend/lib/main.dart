import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/register_screen.dart';
import 'presentation/volunteer/volunteer_shell.dart';
import 'presentation/volunteer/active_task_screen.dart';
import 'presentation/volunteer/profile_screen.dart';
import 'presentation/volunteer/chat_screen.dart';
import 'presentation/foundation/dashboard_screen.dart';
import 'presentation/foundation/create_task_screen.dart';
import 'presentation/foundation/review_screen.dart';
import 'providers/auth_provider.dart';
import 'data/models.dart';

void main() {
  runApp(const ProviderScope(child: DobroSwipeApp()));
}

class DobroSwipeApp extends ConsumerStatefulWidget {
  const DobroSwipeApp({Key? key}) : super(key: key);

  @override
  ConsumerState<DobroSwipeApp> createState() => _DobroSwipeAppState();
}

class _DobroSwipeAppState extends ConsumerState<DobroSwipeApp> {
  GoRouter? _router;
  AuthState? _lastAuthState;

  GoRouter _buildRouter(AuthState authState) {
    return GoRouter(
      initialLocation: _getInitialLocation(authState),
      redirect: (context, state) {
        final isLoggedIn = authState.user != null;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (!isLoggedIn && !isAuthRoute) {
          return '/login';
        }

        if (isLoggedIn && isAuthRoute) {
          if (authState.user!.role == 'volunteer') {
            return '/volunteer';
          } else {
            return '/foundation/dashboard';
          }
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/volunteer', builder: (_, __) => const VolunteerShell()),
        GoRoute(
          path: '/volunteer/active',
          builder: (_, state) {
            final data = state.extra as Map<String, dynamic>;
            return ActiveTaskScreen(
              task: data['task'] as Task,
              initialAssignmentId: data['assignmentId'] as int?,
            );
          },
        ),
        GoRoute(path: '/volunteer/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(
          path: '/volunteer/chat',
          builder: (_, state) {
            final data = state.extra as Map<String, dynamic>;
            return ChatScreen(
              assignmentId: data['assignmentId'] as int,
              taskTitle: data['taskTitle'] as String,
            );
          },
        ),
        GoRoute(path: '/foundation/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/foundation/create_task', builder: (_, __) => const CreateTaskScreen()),
        GoRoute(
          path: '/foundation/review',
          builder: (_, state) => ReviewScreen(taskData: state.extra),
        ),
      ],
    );
  }

  String _getInitialLocation(AuthState authState) {
    if (authState.user == null) return '/login';
    return authState.user!.role == 'volunteer' ? '/volunteer' : '/foundation/dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return MaterialApp(
        title: 'ДоброСвайп',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Only rebuild router when login state actually changes
    final loggedIn = authState.user != null;
    final wasLoggedIn = _lastAuthState?.user != null;
    if (_router == null || loggedIn != wasLoggedIn) {
      _router = _buildRouter(authState);
    }
    _lastAuthState = authState;

    return MaterialApp.router(
      title: 'ДоброСвайп',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router!,
      debugShowCheckedModeBanner: false,
    );
  }
}
