import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';
import '../models/user_profile_model.dart';

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
    String? phone,
  }) async {
    final response =
        await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user != null && response.session != null) {
      await _upsertUserProfile(
        id: user.id,
        fullName: fullName,
        role: role,
        phone: phone,
      );
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
    String? phone,
  }) {
    return _client.from('users').upsert({
      'id': id,
      'full_name': fullName,
      'role': role.toDb(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
  }

  /// Full profile row for the signed-in user, combined with their auth
  /// email — used by the Fulfillment "Your Details" card and the
  /// Settings screen (see SESSION_HANDOFF_phaseAH_fixes.md Phase C/D).
  Future<UserProfileModel?> fetchCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client
        .from('users')
        .select('id, full_name, phone, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return UserProfileModel.fromMap(row, email: user.email ?? '');
  }

  /// Settings screen save — name + phone only. Email is intentionally
  /// left read-only here: changing it goes through Supabase Auth's own
  /// re-verification flow, a separate feature this batch doesn't scope
  /// for (see SESSION_HANDOFF_phaseAH_fixes.md Phase D).
  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('users').update({
      'full_name': fullName,
      'phone': phone.trim().isEmpty ? null : phone.trim(),
    }).eq('id', user.id);
  }

  /// Uploads a profile photo to the same `shop-images` bucket used by
  /// menu items and shop covers, under an `avatars/` prefix — no second
  /// bucket needed (see SESSION_HANDOFF_phaseAH_fixes.md Phase E).
  /// Path is keyed by user id + timestamp so re-uploading doesn't
  /// require a delete-first step.
  Future<String> uploadAvatarImage({
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('uploadAvatarImage called with no signed-in user.');
    }
    final path =
        'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage.from('shop-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('shop-images').getPublicUrl(path);
  }

  /// Writes the uploaded photo's URL to the real `users.avatar_url`
  /// column (ERD.md §2) — this is the column Profile now reads from
  /// instead of the Google-only `userMetadata['avatar_url']` fallback,
  /// so email/password accounts get avatars too.
  Future<void> updateAvatarUrl(String avatarUrl) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('users')
        .update({'avatar_url': avatarUrl}).eq('id', user.id);
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
