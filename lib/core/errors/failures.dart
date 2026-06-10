class AppFailure implements Exception {
  AppFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AgoraFailure extends AppFailure {
  AgoraFailure(super.message, [super.cause]);
}

class FirebaseFailure extends AppFailure {
  FirebaseFailure(super.message, [super.cause]);
}

class NetworkFailure extends AppFailure {
  NetworkFailure(super.message, [super.cause]);
}

class RtmpFailure extends AppFailure {
  RtmpFailure(super.message, [super.cause]);
}
