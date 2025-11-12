import 'package:go_router/go_router.dart';

import 'core/session_state.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'features/device/devices_screen.dart';
import 'features/rewards/rewards_catalog_page.dart';
import 'screens/profile_screen.dart';
import 'screens/home_shell.dart';
import 'screens/metrics_screen.dart';

GoRouter createAppRouter(SessionState session) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      final logged = session.isLoggedIn;

      final isShell =
          path == '/dashboard' ||
          path == '/devices' ||
          path == '/rewards' ||
          path == '/metrics' ||
          path == '/profile';

      if (!logged && isShell) return '/login';
      if (logged && (path == '/login' || path == '/register'))
        return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(path: '/devices', builder: (_, __) => const DevicesScreen()),
          GoRoute(
            path: '/rewards',
            builder: (_, __) => const RewardsCatalogPage(),
          ),
          GoRoute(path: '/metrics', builder: (_, __) => const MetricsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
}
