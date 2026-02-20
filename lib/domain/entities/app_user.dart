class AppUser {
  const AppUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
  });

  final String id;
  final String? name;
  final String? email;
  final String? phone;
}
