import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:async';

import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/models/rtmp_destination.dart';
import '../config/agora_config_repository.dart';
import '../errors/failures.dart';

abstract class IAgoraService {
  RtcEngine? get engine;
  String? get activeChannelName;
  List<int> get currentRemoteUsers;
  Stream<List<int>> get remoteUsers;
  Future<void> initialize();
  Future<void> joinAsHost({required String token, required String channelName});
  Future<void> joinAsAudience({
    required String token,
    required String channelName,
  });
  Future<void> leaveChannel();
  Future<void> setLocalAudioMuted(bool muted);
  Future<void> setLocalVideoMuted(bool muted);
  Future<void> startRtmpPush(RtmpDestination destination);
  Future<void> stopRtmpPush(String pushUrl);
  Future<void> destroy();
}

class AgoraService implements IAgoraService {
  AgoraService(this._logger, this._config);

  final Logger _logger;
  final IAgoraConfigRepository _config;
  RtcEngine? _engine;
  RtcEngineEventHandler? _handler;
  String? _engineAppId;
  String? _activeChannelName;
  String? _joiningChannelName;
  final _remoteUsers = <int>[];
  final _remoteUsersController = StreamController<List<int>>.broadcast();

  @override
  RtcEngine? get engine => _engine;

  @override
  String? get activeChannelName => _activeChannelName;

  @override
  List<int> get currentRemoteUsers => List.unmodifiable(_remoteUsers);

  @override
  Stream<List<int>> get remoteUsers => _remoteUsersController.stream;

  @override
  Future<void> initialize() async {
    try {
      final config = await _config.currentConfig();
      if (_engine != null && _engineAppId != config.appId) {
        await destroy();
      }
      _engine ??= createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: config.appId));
      _engineAppId = config.appId;
      _registerEventHandler();
      await _engine!.enableVideo();
      await _engine!.enableAudio();
    } catch (error) {
      throw AgoraFailure('Unable to initialize Agora engine.', error);
    }
  }

  @override
  Future<void> joinAsHost({
    required String token,
    required String channelName,
  }) async {
    await initialize();
    try {
      if (!_beginJoin(channelName)) return;
      final permissions = await [
        Permission.camera,
        Permission.microphone,
      ].request();
      final denied = permissions.values.any((status) => !status.isGranted);
      if (denied) {
        throw AgoraFailure('Camera and microphone permissions are required.');
      }
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.startPreview();
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
      _activeChannelName = channelName;
    } catch (error) {
      if (_joiningChannelName == channelName) {
        _activeChannelName = null;
      }
      throw AgoraFailure('Unable to join Agora as host.', error);
    } finally {
      if (_joiningChannelName == channelName) {
        _joiningChannelName = null;
      }
    }
  }

  @override
  Future<void> joinAsAudience({
    required String token,
    required String channelName,
  }) async {
    await initialize();
    try {
      if (!_beginJoin(channelName)) return;
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      _activeChannelName = channelName;
    } catch (error) {
      if (_joiningChannelName == channelName) {
        _activeChannelName = null;
      }
      throw AgoraFailure('Unable to join Agora as audience.', error);
    } finally {
      if (_joiningChannelName == channelName) {
        _joiningChannelName = null;
      }
    }
  }

  @override
  Future<void> startRtmpPush(RtmpDestination destination) async {
    if (!destination.enabled) return;
    if (!destination.hasValidUrl || destination.streamKey.isEmpty) {
      throw RtmpFailure(
        'Invalid RTMP destination for ${destination.platformName}.',
      );
    }
    try {
      final transcoding = LiveTranscoding(
        width: 1280,
        height: 720,
        videoBitrate: 2200,
        videoFramerate: 30,
        audioSampleRate: AudioSampleRateType.audioSampleRate44100,
        audioBitrate: 128,
        audioChannels: 2,
      );
      await _engine!.startRtmpStreamWithTranscoding(
        url: destination.pushUrl,
        transcoding: transcoding,
      );
      _logger.i('RTMP push started: ${destination.platformName}');
    } catch (error) {
      throw RtmpFailure('Unable to start RTMP push.', error);
    }
  }

  @override
  Future<void> stopRtmpPush(String pushUrl) async {
    try {
      await _engine?.stopRtmpStream(pushUrl);
    } catch (error) {
      throw RtmpFailure('Unable to stop RTMP push.', error);
    }
  }

  @override
  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    _activeChannelName = null;
    _joiningChannelName = null;
    _remoteUsers.clear();
    _remoteUsersController.add(List.unmodifiable(_remoteUsers));
  }

  @override
  Future<void> setLocalAudioMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  @override
  Future<void> setLocalVideoMuted(bool muted) async {
    await _engine?.muteLocalVideoStream(muted);
  }

  @override
  Future<void> destroy() async {
    await _engine?.release();
    _engine = null;
    _handler = null;
    _engineAppId = null;
    _activeChannelName = null;
    _joiningChannelName = null;
    _remoteUsers.clear();
    _remoteUsersController.add(List.unmodifiable(_remoteUsers));
  }

  bool _beginJoin(String channelName) {
    if (_activeChannelName == channelName ||
        _joiningChannelName == channelName) {
      _logger.i('Agora join skipped; already joining/joined: $channelName');
      return false;
    }
    _joiningChannelName = channelName;
    _activeChannelName = channelName;
    _remoteUsers.clear();
    _remoteUsersController.add(List.unmodifiable(_remoteUsers));
    return true;
  }

  void _registerEventHandler() {
    if (_handler != null || _engine == null) return;
    _handler = RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        _logger.i(
          'Agora joined channel: ${connection.channelId}, uid: ${connection.localUid}',
        );
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        _logger.i('Agora remote user joined: $remoteUid');
        _addRemoteUser(remoteUid);
      },
      onFirstRemoteVideoFrame: (connection, remoteUid, width, height, elapsed) {
        _logger.i(
          'Agora first remote video frame: $remoteUid ${width}x$height',
        );
        _addRemoteUser(remoteUid);
      },
      onRemoteVideoStateChanged:
          (connection, remoteUid, state, reason, elapsed) {
            if (state == RemoteVideoState.remoteVideoStateStarting ||
                state == RemoteVideoState.remoteVideoStateDecoding) {
              _logger.i('Agora remote video active: $remoteUid');
              _addRemoteUser(remoteUid);
            }
          },
      onUserOffline: (connection, remoteUid, reason) {
        _logger.i('Agora remote user offline: $remoteUid');
        _remoteUsers.remove(remoteUid);
        _remoteUsersController.add(List.unmodifiable(_remoteUsers));
      },
      onLeaveChannel: (connection, stats) {
        _remoteUsers.clear();
        _remoteUsersController.add(List.unmodifiable(_remoteUsers));
      },
      onError: (error, message) {
        _logger.e('Agora error: $error $message');
      },
    );
    _engine!.registerEventHandler(_handler!);
  }

  void _addRemoteUser(int remoteUid) {
    if (remoteUid == 0 || _remoteUsers.contains(remoteUid)) return;
    _remoteUsers.add(remoteUid);
    _remoteUsersController.add(List.unmodifiable(_remoteUsers));
  }
}
