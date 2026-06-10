import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photo,
    required this.role,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String photo;
  final String role;
  final DateTime createdAt;

  factory AppUser.guest(String uid) => AppUser(
    uid: uid,
    name: 'Guest Viewer',
    email: '',
    photo: '',
    role: 'user',
    createdAt: DateTime.now(),
  );

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'] as String? ?? '',
    name: map['name'] as String? ?? 'Mini User',
    email: map['email'] as String? ?? '',
    photo: map['photo'] as String? ?? '',
    role: map['role'] as String? ?? 'user',
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'photo': photo,
    'role': role,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  @override
  List<Object?> get props => [uid, name, email, photo, role, createdAt];
}
