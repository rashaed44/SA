class SaloUser {
  const SaloUser({
    this.uid,
    this.id,
    required this.username,
    required this.displayName,
    this.email,
  });

  /// Firebase Auth UID. Public profile documents never contain the email.
  final String? uid;

  /// Kept only for compatibility with historical REST payloads during migration.
  final int? id;
  final String username;
  final String displayName;
  final String? email;

  factory SaloUser.fromJson(Map<String, dynamic> json) => SaloUser(
    uid: json['uid']?.toString(),
    id: json['id'] is int ? json['id'] as int : null,
    username: (json['username'] ?? '').toString(),
    displayName: (json['displayName'] ?? json['name'] ?? json['username'] ?? '')
        .toString(),
    // Do not populate email from public profile/API payloads.
    email: null,
  );
}

class SaloSession {
  const SaloSession({required this.token, required this.user});
  final String token;
  final SaloUser user;
}
