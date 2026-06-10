import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';

class AgoraConfig extends Equatable {
  const AgoraConfig({
    required this.appId,
    required this.channelName,
    required this.tempToken,
    this.updatedAt,
    this.updatedBy = '',
  });

  factory AgoraConfig.defaults() => const AgoraConfig(
    appId: AppConstants.agoraAppId,
    channelName: AppConstants.agoraChannel,
    tempToken: AppConstants.agoraTempToken,
  );

  factory AgoraConfig.fromMap(Map<String, dynamic> map) => AgoraConfig(
    appId: map['appId'] as String? ?? AppConstants.agoraAppId,
    channelName: map['channelName'] as String? ?? AppConstants.agoraChannel,
    tempToken: map['tempToken'] as String? ?? AppConstants.agoraTempToken,
    updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    updatedBy: map['updatedBy'] as String? ?? '',
  );

  final String appId;
  final String channelName;
  final String tempToken;
  final DateTime? updatedAt;
  final String updatedBy;

  Map<String, dynamic> toMap({String? updatedBy}) => {
    'appId': appId,
    'channelName': channelName,
    'tempToken': tempToken,
    'updatedBy': updatedBy ?? this.updatedBy,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  List<Object?> get props => [
    appId,
    channelName,
    tempToken,
    updatedAt,
    updatedBy,
  ];
}
