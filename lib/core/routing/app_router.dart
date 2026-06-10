import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/resource_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/kendaraan_search/presentation/kendaraan_search_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../widgets/admin_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = GoRouterRefreshNotifier();

  ref
    ..onDispose(authNotifier.dispose)
    ..listen(authControllerProvider, (_, next) {
      authNotifier.refresh();
    });

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final signedIn = auth.valueOrNull != null;
      final loggingIn = state.matchedLocation == '/login';
      if (auth.isLoading) return null;
      if (!signedIn && !loggingIn) return '/login';
      if (signedIn && loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage()),
          GoRoute(
              path: '/pencarian',
              builder: (context, state) => const KendaraanSearchPage()),
          GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage()),
          GoRoute(
            path: '/resource/:key',
            builder: (context, state) =>
                ResourcePage(resourceKey: state.pathParameters['key']!),
          ),
        ],
      ),
    ],
  );
});

class GoRouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}
