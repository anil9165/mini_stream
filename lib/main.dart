import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_bloc.dart';
import 'features/analytics/presentation/analytics_bloc.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/app_gate.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/live_stream/domain/live_stream_repository.dart';
import 'features/live_stream/domain/token_repository.dart';
import 'features/live_stream/presentation/live_stream_bloc.dart';
import 'features/rtmp/domain/rtmp_repository.dart';
import 'features/rtmp/presentation/rtmp_bloc.dart';
import 'features/analytics/domain/analytics_repository.dart';
import 'core/services/agora_service.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      if (!kIsWeb) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      }
      await configureDependencies();
      runApp(const MiniLiveApp());
    },
    (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

class MiniLiveApp extends StatelessWidget {
  const MiniLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(sl<IAuthRepository>())),
        BlocProvider(
          create: (_) => LiveStreamBloc(
            sl<ILiveStreamRepository>(),
            sl<ITokenRepository>(),
            sl<IAgoraService>(),
            sl<IAnalyticsRepository>(),
          ),
        ),
        BlocProvider(create: (_) => RtmpBloc(sl<IRtmpRepository>())),
        BlocProvider(create: (_) => AnalyticsBloc()),
        BlocProvider(create: (_) => AdminBloc()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const AppGate(),
      ),
    );
  }
}
