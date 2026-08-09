import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/user_role.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/user_profile_model.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Fires on sign in, sign out, token refresh.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Re-fetches the `users.role` row whenever auth state changes.
final currentUserRoleProvider = FutureProvider<UserRole?>((ref) async {
  ref.watch(authStateChangesProvider); // dependency: re-run on auth changes
  return ref.watch(authRepositoryProvider).fetchCurrentUserRole();
});

/// The signed-in user's real `users.full_name`/`phone` — not the OAuth
/// metadata fallback. Used by Fulfillment's "Your Details" card and
/// the Settings screen. `.autoDispose` because both screens are
/// transient; invalidate manually after a Settings save (see
/// settings_screen.dart) rather than relying on a stream.
final currentUserProfileProvider =
    FutureProvider.autoDispose<UserProfileModel?>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).fetchCurrentUserProfile();
});

/// Holds the role chosen on Signup's role picker for the gap between
/// tapping "Continue with Google" and the OAuth redirect landing back
/// in the app. Consumed + cleared by SplashScreen, and explicitly
/// nulled by Login's Google button so a stale Signup selection never
/// bleeds into a Login-initiated Google sign-in for a different account.
final pendingSignupRoleProvider = StateProvider<UserRole?>((ref) => null);
