import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../config/agora_config_repository.dart';
import '../../features/analytics/data/firestore_analytics_repository.dart';
import '../../features/analytics/domain/analytics_repository.dart';
import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/live_stream/data/firestore_live_stream_repository.dart';
import '../../features/live_stream/domain/live_stream_repository.dart';
import '../../features/live_stream/domain/token_repository.dart';
import '../../features/rtmp/data/firestore_rtmp_repository.dart';
import '../../features/rtmp/domain/rtmp_repository.dart';
import '../network/network_info.dart';
import '../services/agora_service.dart';
import '../services/local_storage_service.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl
    ..registerLazySingleton(Logger.new)
    ..registerLazySingleton<INetworkInfo>(NetworkInfo.new)
    ..registerLazySingleton(() => FirebaseAuth.instance)
    ..registerLazySingleton(() => FirebaseFirestore.instance)
    ..registerLazySingleton<IAgoraConfigRepository>(
      () => FirestoreAgoraConfigRepository(sl()),
    )
    ..registerLazySingleton<ITokenRepository>(() => StaticTokenRepository(sl()))
    ..registerLazySingleton<IAgoraService>(() => AgoraService(sl(), sl()))
    ..registerLazySingleton<IAuthRepository>(
      () => FirebaseAuthRepository(sl(), sl()),
    )
    ..registerLazySingleton<ILiveStreamRepository>(
      () => FirestoreLiveStreamRepository(sl(), sl()),
    )
    ..registerLazySingleton<IRtmpRepository>(
      () => FirestoreRtmpRepository(sl()),
    )
    ..registerLazySingleton<IAnalyticsRepository>(
      () => FirestoreAnalyticsRepository(sl()),
    );

  final storage = LocalStorageService();
  await storage.initialize();
  sl.registerSingleton(storage);
}
