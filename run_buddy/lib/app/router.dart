import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/onboarding_page.dart';
import '../features/home/presentation/home_dashboard_page.dart';
import '../features/friends/presentation/friends_list_page.dart';
import '../features/runs/presentation/start_run_page.dart';
import '../features/runs/presentation/run_lobby_page.dart';
import '../features/runs/presentation/run_history_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/active_run/presentation/active_shared_run_page.dart';
import '../features/active_run/presentation/run_summary_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.splash,
  routes: [
    GoRoute(
      path: RouteNames.splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: RouteNames.onboarding,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RouteNames.register,
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const HomeDashboardPage(),
    ),
    GoRoute(
      path: RouteNames.friends,
      builder: (context, state) => const FriendsListPage(),
    ),
    GoRoute(
      path: RouteNames.history,
      builder: (context, state) => const RunHistoryPage(),
    ),
    GoRoute(
      path: RouteNames.profile,
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: RouteNames.startRun,
      builder: (context, state) => const StartRunPage(),
    ),
    GoRoute(
      path: RouteNames.runLobby,
      builder: (context, state) => const RunLobbyPage(),
    ),
    GoRoute(
      path: RouteNames.activeRun,
      builder: (context, state) => const ActiveSharedRunPage(),
    ),
    GoRoute(
      path: RouteNames.runSummary,
      builder: (context, state) => const RunSummaryPage(),
    ),
  ],
);
