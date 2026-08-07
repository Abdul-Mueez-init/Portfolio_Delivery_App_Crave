import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import 'placeholder_screens.dart';
import '../../features/shops/presentation/screens/home_screen.dart';
import '../../features/shops/presentation/screens/shop_detail_screen.dart';
import '../../features/auth/presentation/screens/role_picker_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/orders/presentation/screens/fulfillment_selection_screen.dart';
import '../../features/bookings/presentation/screens/booking_confirmation_screen.dart';

abstract class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const customerHome = '/home';
  static const shopDetail = '/shop'; // used as '/shop/:shopId'
  static const cart = '/cart';
  static const fulfillment = '/fulfillment';
  static const bookingConfirmation =
      '/booking-confirmation'; // used as '/booking-confirmation/:bookingId'
  static const ownerDashboard = '/owner/dashboard';
  static const shopOnboarding = '/owner/shop-onboarding';
  static const chooseRole = '/choose-role';

  static const publicRoutes = {splash, onboarding, login, signup};
}

/// Bridges a Stream to a Listenable so go_router re-evaluates `redirect`
/// every time Supabase's auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authClient = Supabase.instance.client.auth;

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authClient.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = authClient.currentSession != null;
      final location = state.matchedLocation;
      final goingToPublicRoute = AppRoutes.publicRoutes.contains(location);

      if (!loggedIn && !goingToPublicRoute) {
        return AppRoutes.login;
      }

      // Logged in but sitting on an auth screen — this is the case right
      // after a Google OAuth redirect lands back in the app. Funnel
      // through Splash, which knows how to fetch role / ensure a
      // profile exists / route on from there.
      final onAuthScreen = {
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.signup
      }.contains(location);
      if (loggedIn && onAuthScreen) {
        return AppRoutes.splash;
      }

      return null;
    },
    routes: [
      GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen()),
      GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.signup,
          builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: AppRoutes.customerHome,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.shopDetail}/:shopId',
        builder: (context, state) {
          final shopId = state.pathParameters['shopId']!;
          return ShopDetailScreen(shopId: shopId);
        },
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.fulfillment,
        builder: (context, state) => const FulfillmentSelectionScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.bookingConfirmation}/:bookingId',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return BookingConfirmationScreen(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: AppRoutes.ownerDashboard,
        builder: (context, state) => const OwnerDashboardPlaceholder(),
      ),
      GoRoute(
        path: AppRoutes.shopOnboarding,
        builder: (context, state) => const ShopOnboardingPlaceholder(),
      ),
      GoRoute(
          path: AppRoutes.chooseRole,
          builder: (context, state) => const RolePickerScreen())
    ],
  );
});
