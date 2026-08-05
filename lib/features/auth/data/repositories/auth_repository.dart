import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Best-effort display name for a first-time Google sign-in, which
  /// never goes through the Signup form's name field.
  String get currentUserDisplayNameFallback {
    final user = currentUser;
    if (user == null) return 'Crave User';
    final metadata = user.userMetadata;
    final name = metadata?['full_name'] ?? metadata?['name'];
    if (name is String && name.trim().isNotEmpty) return name;
    return user.email?.split('@').first ?? 'Crave User';
  }

  /// Email/password signup. Immediately writes the `users` row with the
  /// chosen role — this is the write `go_router`'s redirect depends on.
  ///
  /// NOTE: this only works synchronously if "Confirm email" is OFF in
  /// Supabase Auth settings (so signUp() returns a live session right
  /// away). If you want email confirmation on, this insert has to move
  /// to first-login-after-confirmation instead — flag it if that's the case.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final response =
        await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user != null && response.session != null) {
      await _upsertUserProfile(id: user.id, fullName: fullName, role: role);
    }
    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Opens the OAuth flow. Redirect URI must match what's wired into
  /// Supabase Auth's Google provider from Phase 0 console setup.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo:
          'io.supabase.crave://login-callback/', // TODO: confirm this matches your Phase 0 setup
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> _upsertUserProfile({
    required String id,
    required String fullName,
    required UserRole role,
  }) {
    return _client.from('users').upsert({
      'id': id,
      'full_name': fullName,
      'role': role.toDb(),
    });
  }

  /// Google sign-in has no role-picker step of its own. Call this right
  /// after a successful Google auth — it only writes a profile (with the
  /// given role) if one doesn't already exist, so it never clobbers an
  /// existing user's role on a normal login.
  Future<void> ensureProfileWithRole({
    required String fullName,
    required UserRole role,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final existing = await _client
        .from('users')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing == null) {
      await _upsertUserProfile(id: user.id, fullName: fullName, role: role);
    }
  }

  Future<UserRole?> fetchCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return UserRoleX.fromDb(row['role'] as String);
  }
}
