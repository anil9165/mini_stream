import '../../../shared/models/app_user.dart';

abstract class IAuthRepository {
  Stream<AppUser?> authState();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> createAccount(
    String name,
    String email,
    String password,
    String role,
  );
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInAsGuest();
  Future<void> signOut();
}
