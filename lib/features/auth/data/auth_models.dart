class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.status,
    this.photo,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? status;
  final String? photo;

  bool get canUseDesktop {
    final normalized = role.toLowerCase();
    return normalized == 'admin' || normalized == 'super admin' || normalized == 'operator';
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '-',
      email: json['email']?.toString() ?? '-',
      role: json['role']?.toString() ?? '',
      phone: json['phone']?.toString(),
      status: json['status']?.toString(),
      photo: json['photo']?.toString(),
    );
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AuthUser user;
  final String token;
}
