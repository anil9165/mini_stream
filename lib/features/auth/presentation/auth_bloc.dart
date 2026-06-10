import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import '../../../shared/models/app_user.dart';
import '../domain/auth_repository.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthGuestRequested extends AuthEvent {}

class AuthGoogleRequested extends AuthEvent {}

class AuthSessionRequested extends AuthEvent {}

class AuthEmailRequested extends AuthEvent {
  const AuthEmailRequested(this.email, this.password);
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class AuthCreateAccountRequested extends AuthEvent {
  const AuthCreateAccountRequested(
    this.name,
    this.email,
    this.password,
    this.role,
  );
  final String name;
  final String email;
  final String password;
  final String role;
  @override
  List<Object?> get props => [name, email, password, role];
}

class AuthSignedOut extends AuthEvent {}

class _AuthUserChanged extends AuthEvent {
  const _AuthUserChanged(this.user);
  final AppUser? user;
  @override
  List<Object?> get props => [user];
}

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final AppUser user;
  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(AuthInitial()) {
    on<AuthSessionRequested>(_session);
    on<AuthGuestRequested>(_guest);
    on<AuthGoogleRequested>(_google);
    on<AuthEmailRequested>(_email);
    on<AuthCreateAccountRequested>(_createAccount);
    on<AuthSignedOut>(_signOut);
    on<_AuthUserChanged>(_userChanged);
  }

  final IAuthRepository _repository;
  StreamSubscription<AppUser?>? _subscription;

  Future<void> _session(
    AuthSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _subscription?.cancel();
    _subscription = _repository.authState().listen(
      (user) => add(_AuthUserChanged(user)),
      onError: (Object error) => addError(error),
    );
  }

  void _userChanged(_AuthUserChanged event, Emitter<AuthState> emit) {
    final user = event.user;
    emit(user == null ? Unauthenticated() : Authenticated(user));
  }

  Future<void> _guest(AuthGuestRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      emit(Authenticated(await _repository.signInAsGuest()));
    } catch (error) {
      emit(AuthError(error.toString()));
    }
  }

  Future<void> _email(AuthEmailRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      emit(
        Authenticated(
          await _repository.signInWithEmail(event.email, event.password),
        ),
      );
    } catch (error) {
      emit(AuthError(error.toString()));
    }
  }

  Future<void> _google(
    AuthGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      emit(Authenticated(await _repository.signInWithGoogle()));
    } catch (error) {
      emit(AuthError(error.toString()));
    }
  }

  Future<void> _createAccount(
    AuthCreateAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      emit(
        Authenticated(
          await _repository.createAccount(
            event.name,
            event.email,
            event.password,
            event.role,
          ),
        ),
      );
    } catch (error) {
      emit(AuthError(error.toString()));
    }
  }

  Future<void> _signOut(AuthSignedOut event, Emitter<AuthState> emit) async {
    await _repository.signOut();
    emit(Unauthenticated());
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
