import 'package:equatable/equatable.dart';

class RtmpDestination extends Equatable {
  const RtmpDestination({
    required this.destinationId,
    required this.platformName,
    required this.rtmpUrl,
    required this.streamKey,
    this.enabled = true,
  });

  final String destinationId;
  final String platformName;
  final String rtmpUrl;
  final String streamKey;
  final bool enabled;

  String get pushUrl {
    final base = rtmpUrl.endsWith('/')
        ? rtmpUrl.substring(0, rtmpUrl.length - 1)
        : rtmpUrl;
    return '$base/$streamKey';
  }

  bool get hasValidUrl => Uri.tryParse(rtmpUrl)?.scheme == 'rtmp';

  factory RtmpDestination.fromMap(Map<String, dynamic> map) => RtmpDestination(
    destinationId: map['destinationId'] as String? ?? '',
    platformName: map['platformName'] as String? ?? '',
    rtmpUrl: map['rtmpUrl'] as String? ?? '',
    streamKey: map['streamKey'] as String? ?? '',
    enabled: map['enabled'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'destinationId': destinationId,
    'platformName': platformName,
    'rtmpUrl': rtmpUrl,
    'streamKey': streamKey,
    'enabled': enabled,
  };

  @override
  List<Object?> get props => [
    destinationId,
    platformName,
    rtmpUrl,
    streamKey,
    enabled,
  ];
}
