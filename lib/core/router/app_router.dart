import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/shops/presentation/screens/home_screen.dart';
import '../../features/shops/presentation/screens/shop_detail_screen.dart';
import '../../features/auth/presentation/screens/role_picker_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/orders/presentation/screens/fulfillment_selection_screen.dart';
import '../../features/orders/presentation/screens/checkout_screen.dart';
import '../../features/orders/presentation/screens/order_tracking_screen.dart';
import '../../features/orders/presentation/screens/order_queue_screen.dart';
import '../../features/bookings/presentation/screens/booking_confirmation_screen.dart';
import '../../features/bookings/presentation/screens/booking_calendar_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/shops/presentation/screens/shop_onboarding_screen.dart';
import '../../features/shops/presentation/screens/shop_settings_screen.dart';
import '../../features/shops/presentation/screens/dashboard_home_screen.dart';
import '../../features/shops/presentation/screens/menu_management_screen.dart';
import '../../features/shops/presentation/screens/menu_item_form_screen.dart';

abstract class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const customerHome = '/home';
  static const shopDetail = '/shop'; // used as '/shop/:shopId'
  static const cart = '/cart';
  static const fulfillment = '/fulfillment';
  static const checkout = '/checkout';
  static const orderTracking =
      '/order-tracking'; // used as '/order-tracking/:orderId'
  static const bookingConfirmation =
      '/booking-confirmation'; // used as '/booking-confirmation/:bookingId'
  static const activity = '/activity';
  static const profile = '/profile';
  static const settings = '/settings';
  static const ownerDashboard = '/owner/dashboard';
  static const shopOnboarding = '/owner/shop-onboarding';
  static const ownerOrderQueue = '/owner/orders';
  static const ownerBookingCalendar = '/owner/bookings';
  static const ownerMenuManagement = '/owner/menu';
  // extra: MenuItemFormArgs (menu_item_form_screen.dart)
  static const ownerMenuItemForm = '/owner/menu/item-form';
  static const ownerShopSettings = '/owner/settings';
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
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.orderTracking}/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.bookingConfirmation}/:bookingId',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return BookingConfirmationScreen(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: AppRoutes.activity,
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      // --- Owner routes ---
      GoRoute(
        path: AppRoutes.ownerDashboard,
        builder: (context, state) => const DashboardHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopOnboarding,
        builder: (context, state) => const ShopOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerOrderQueue,
        builder: (context, state) => const OrderQueueScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerBookingCalendar,
        builder: (context, state) => const BookingCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerMenuManagement,
        builder: (context, state) => const MenuManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerMenuItemForm,
        builder: (context, state) {
          final args = state.extra as MenuItemFormArgs;
          return MenuItemFormScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.ownerShopSettings,
        builder: (context, state) => const ShopSettingsScreen(),
      ),
      GoRoute(
          path: AppRoutes.chooseRole,
          builder: (context, state) => const RolePickerScreen())
    ],
  );
});
