import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/models/app_user.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements IAuthRepository {
  FirebaseAuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  Future<void>? _googleInit;

  @override
  Stream<AppUser?> authState() =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null) return null;
        final existing = await _readUser(user.uid);
        if (existing != null) return existing;
        final appUser = AppUser(
          uid: user.uid,
          name: user.displayName ?? 'Mini User',
          email: user.email ?? '',
          photo: user.photoURL ?? '',
          role: _roleForEmail(user.email ?? '', fallback: 'user'),
          createdAt: DateTime.now(),
        );
        await _saveUser(appUser);
        return appUser;
      });

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw FirebaseFailure('No Firebase user returned.');
      final existing = await _readUser(user.uid);
      if (existing != null) return existing;
      final appUser = AppUser(
        uid: user.uid,
        name: user.displayName ?? email.split('@').first,
        email: user.email ?? email,
        photo: user.photoURL ?? '',
        role: _roleForEmail(user.email ?? email, fallback: 'user'),
        createdAt: DateTime.now(),
      );
      await _saveUser(appUser);
      return appUser;
    } on FirebaseAuthException catch (error) {
      throw FirebaseFailure(error.message ?? 'Email sign-in failed.', error);
    } catch (error) {
      throw FirebaseFailure('Email sign-in failed.', error);
    }
  }

  @override
  Future<AppUser> createAccount(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      if (email.trim().toLowerCase() == 'superadmin@gmail.com') {
        throw FirebaseFailure(
          'Super admin account already fixed hai. Register nahi kar sakte, login use karo.',
        );
      }
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      final appUser = AppUser(
        uid: credential.user!.uid,
        name: name.trim().isEmpty ? email.split('@').first : name.trim(),
        email: email,
        photo: '',
        role: _roleForEmail(
          email,
          fallback: role == 'admin' ? 'admin' : 'user',
        ),
        createdAt: DateTime.now(),
      );
      await _saveUser(appUser);
      return appUser;
    } on FirebaseAuthException catch (error) {
      throw FirebaseFailure(error.message ?? 'Account creation failed.', error);
    } catch (error) {
      throw FirebaseFailure('Account creation failed.', error);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      _googleInit ??= GoogleSignIn.instance.initialize();
      await _googleInit;
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        throw FirebaseFailure('No Firebase user returned from Google login.');
      }
      final existing = await _readUser(firebaseUser.uid);
      if (existing != null) return existing;
      final appUser = AppUser(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? googleUser.displayName ?? 'Mini User',
        email: firebaseUser.email ?? googleUser.email,
        photo: firebaseUser.photoURL ?? googleUser.photoUrl ?? '',
        role: _roleForEmail(
          firebaseUser.email ?? googleUser.email,
          fallback: 'user',
        ),
        createdAt: DateTime.now(),
      );
      await _saveUser(appUser);
      return appUser;
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('developer') || text.contains('10:')) {
        throw FirebaseFailure(
          'Google login config error. Confirm SHA-1/SHA-256 are added in Firebase and Google Sign-In is enabled.',
          error,
        );
      }
      throw FirebaseFailure(
        'Google login failed. Please try email login or guest login.',
        error,
      );
    }
  }

  @override
  Future<AppUser> signInAsGuest() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = AppUser.guest(credential.user!.uid);
      await _saveUser(user);
      return user;
    } catch (error) {
      throw FirebaseFailure('Guest login failed.', error);
    }
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  Future<void> _saveUser(AppUser user) {
    return _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<AppUser?> _readUser(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) return null;
    final appUser = AppUser.fromMap(snapshot.data()!);
    final expectedRole = _roleForEmail(appUser.email, fallback: appUser.role);
    if (expectedRole != appUser.role) {
      final updated = AppUser(
        uid: appUser.uid,
        name: appUser.name,
        email: appUser.email,
        photo: appUser.photo,
        role: expectedRole,
        createdAt: appUser.createdAt,
      );
      await _saveUser(updated);
      return updated;
    }
    return appUser;
  }

  String _roleForEmail(String email, {required String fallback}) {
    if (email.trim().toLowerCase() == 'superadmin@gmail.com') {
      return 'superadmin';
    }
    return fallback;
  }
}
