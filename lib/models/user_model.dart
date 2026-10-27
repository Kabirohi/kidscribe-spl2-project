import 'dart:convert';

class UserModel {
  final String email;
  final String password;
  final String name;
  final String role;
  UserModel({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
  });


  Map<String, dynamic> toMap() => {
    'email': email,
    'password': password,
    'name': name,
    'role': role,
  };


  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    email: map['email'] ?? '',
    password: map['password'] ?? '',
    name: map['name'] ?? '',
    role: map['role'] ?? 'Parent',
  );

  // Convert to a JSON string (for storage)
  String toJson() => jsonEncode(toMap());

  // Create from a JSON string
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(jsonDecode(source));
}
