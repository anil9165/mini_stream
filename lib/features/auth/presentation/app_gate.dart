import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../live_stream/presentation/dashboard_page.dart';
import 'auth_bloc.dart';
import 'auth_page.dart';
import 'splash_page.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.read<AuthBloc>().add(AuthSessionRequested());
    setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) return const SplashPage();
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return DashboardPage(user: state.user);
        }
        if (state is AuthInitial || state is AuthLoading) {
          return const SplashPage();
        }
        return const AuthPage();
      },
    );
  }
}
