import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class LiveStream extends Equatable {
  const LiveStream({
    required this.streamId,
    required this.hostId,
    required this.title,
    required this.description,
    required this.channelName,
    required this.status,
    required this.viewerCount,
    this.hostPresent = false,
    this.hostMicMuted = false,
    this.hostCameraOff = false,
    this.thumbnailUrl = '',
    this.startedAt,
    this.endedAt,
  });

  final String streamId;
  final String hostId;
  final String title;
  final String description;
  final String channelName;
  final String status;
  final int viewerCount;
  final bool hostPresent;
  final bool hostMicMuted;
  final bool hostCameraOff;
  final String thumbnailUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;

  LiveStream copyWith({
    String? status,
    int? viewerCount,
    bool? hostPresent,
    bool? hostMicMuted,
    bool? hostCameraOff,
    DateTime? startedAt,
    DateTime? endedAt,
  }) => LiveStream(
    streamId: streamId,
    hostId: hostId,
    title: title,
    description: description,
    channelName: channelName,
    status: status ?? this.status,
    viewerCount: viewerCount ?? this.viewerCount,
    hostPresent: hostPresent ?? this.hostPresent,
    hostMicMuted: hostMicMuted ?? this.hostMicMuted,
    hostCameraOff: hostCameraOff ?? this.hostCameraOff,
    thumbnailUrl: thumbnailUrl,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
  );

  factory LiveStream.fromMap(Map<String, dynamic> map) => LiveStream(
    streamId: map['streamId'] as String? ?? '',
    hostId: map['hostId'] as String? ?? '',
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    channelName: map['channelName'] as String? ?? '',
    status: map['status'] as String? ?? 'draft',
    viewerCount: map['viewerCount'] as int? ?? 0,
    hostPresent: map['hostPresent'] as bool? ?? false,
    hostMicMuted: map['hostMicMuted'] as bool? ?? false,
    hostCameraOff: map['hostCameraOff'] as bool? ?? false,
    thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
    startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
    endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
  );

  Map<String, dynamic> toMap() => {
    'streamId': streamId,
    'hostId': hostId,
    'title': title,
    'description': description,
    'channelName': channelName,
    'status': status,
    'viewerCount': viewerCount,
    'hostPresent': hostPresent,
    'hostMicMuted': hostMicMuted,
    'hostCameraOff': hostCameraOff,
    'thumbnailUrl': thumbnailUrl,
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
  };

  @override
  List<Object?> get props => [
    streamId,
    hostId,
    title,
    description,
    channelName,
    status,
    viewerCount,
    hostPresent,
    hostMicMuted,
    hostCameraOff,
    thumbnailUrl,
    startedAt,
    endedAt,
  ];
}
