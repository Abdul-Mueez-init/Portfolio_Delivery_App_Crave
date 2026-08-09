/// Lightweight read model for the signed-in user's own `users` row,
/// combined with the auth-only `email` field (which lives on
/// `auth.users`, not the `users` table — see ERD.md §2).
///
/// Used anywhere a screen needs the *real* full_name/phone from the
/// database rather than the Google OAuth metadata fallback
/// (`AuthRepository.currentUserDisplayNameFallback`) — e.g. the
/// Fulfillment "Your Details" card and the Settings screen. See
/// SESSION_HANDOFF_phaseAH_fixes.md Phase C/D.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String email;
  final String? avatarUrl;

  factory UserProfileModel.fromMap(
    Map<String, dynamic> map, {
    required String email,
  }) {
    return UserProfileModel(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      phone: map['phone'] as String?,
      email: email,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
