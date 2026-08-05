import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/user_role.dart';
import '../data/repositories/auth_repository.dart';

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

/// Holds the role chosen on Signup's role picker for the gap between
/// tapping "Continue with Google" and the OAuth redirect landing back
/// in the app. Consumed + cleared by SplashScreen, and explicitly
/// nulled by Login's Google button so a stale Signup selection never
/// bleeds into a Login-initiated Google sign-in for a different account.
final pendingSignupRoleProvider = StateProvider<UserRole?>((ref) => null);
