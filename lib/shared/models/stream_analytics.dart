import 'package:cloud_firestore/cloud_firestore.dart';

class StreamAnalytics {
  const StreamAnalytics({
    required this.streamId,
    required this.duration,
    required this.peakViewers,
    required this.watchTime,
    required this.rtmpSuccessRate,
  });

  final String streamId;
  final Duration duration;
  final int peakViewers;
  final Duration watchTime;
  final double rtmpSuccessRate;

  Map<String, dynamic> toMap() => {
    'streamId': streamId,
    'duration': duration.inSeconds,
    'peakViewers': peakViewers,
    'watchTime': watchTime.inSeconds,
    'rtmpSuccessRate': rtmpSuccessRate,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
