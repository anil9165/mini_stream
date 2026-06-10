import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/agora_service.dart';
import '../../../shared/models/live_stream.dart';
import '../../../shared/models/rtmp_destination.dart';
import '../../../shared/models/stream_analytics.dart';
import '../../analytics/domain/analytics_repository.dart';
import '../domain/live_stream_repository.dart';
import '../domain/token_repository.dart';

sealed class LiveStreamEvent extends Equatable {
  const LiveStreamEvent();
  @override
  List<Object?> get props => [];
}

class WatchLiveStreams extends LiveStreamEvent {}

class CreateLive extends LiveStreamEvent {
  const CreateLive({
    required this.hostId,
    required this.hostRole,
    required this.title,
    required this.description,
  });
  final String hostId;
  final String hostRole;
  final String title;
  final String description;
  @override
  List<Object?> get props => [hostId, hostRole, title, description];
}

class StartLive extends LiveStreamEvent {
  const StartLive(this.stream, this.destinations, {required this.hostRole});
  final LiveStream stream;
  final List<RtmpDestination> destinations;
  final String hostRole;
  @override
  List<Object?> get props => [stream, destinations, hostRole];
}

class JoinLive extends LiveStreamEvent {
  const JoinLive(this.stream);
  final LiveStream stream;
  @override
  List<Object?> get props => [stream];
}

class RejoinHostLive extends LiveStreamEvent {
  const RejoinHostLive(this.stream, {required this.hostRole});
  final LiveStream stream;
  final String hostRole;
  @override
  List<Object?> get props => [stream, hostRole];
}

class LeaveLive extends LiveStreamEvent {
  const LeaveLive(this.stream);
  final LiveStream stream;
  @override
  List<Object?> get props => [stream];
}

class LeaveHostRoom extends LiveStreamEvent {
  const LeaveHostRoom(this.stream);
  final LiveStream stream;
  @override
  List<Object?> get props => [stream];
}

class HostControlsChanged extends LiveStreamEvent {
  const HostControlsChanged({
    required this.stream,
    required this.micMuted,
    required this.cameraOff,
  });

  final LiveStream stream;
  final bool micMuted;
  final bool cameraOff;

  @override
  List<Object?> get props => [stream, micMuted, cameraOff];
}

class EndLive extends LiveStreamEvent {
  const EndLive(this.stream, this.destinations);
  final LiveStream stream;
  final List<RtmpDestination> destinations;
  @override
  List<Object?> get props => [stream, destinations];
}

class DeleteLive extends LiveStreamEvent {
  const DeleteLive(this.stream, this.destinations);
  final LiveStream stream;
  final List<RtmpDestination> destinations;
  @override
  List<Object?> get props => [stream, destinations];
}

class _LiveStreamsUpdated extends LiveStreamEvent {
  const _LiveStreamsUpdated(this.streams);
  final List<LiveStream> streams;
  @override
  List<Object?> get props => [streams];
}

class _LiveStreamsFailed extends LiveStreamEvent {
  const _LiveStreamsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

sealed class LiveStreamState extends Equatable {
  const LiveStreamState();
  @override
  List<Object?> get props => [];
}

class LiveStudioState extends LiveStreamState {
  const LiveStudioState({
    this.streams = const [],
    this.createdStream,
    this.activeHostStream,
    this.joinedStream,
    this.rtmpDestinations = const [],
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  final List<LiveStream> streams;
  final LiveStream? createdStream;
  final LiveStream? activeHostStream;
  final LiveStream? joinedStream;
  final List<RtmpDestination> rtmpDestinations;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  bool get isHostLive => activeHostStream != null;
  bool get isAudienceLive => joinedStream != null;

  LiveStudioState copyWith({
    List<LiveStream>? streams,
    Object? createdStream = _sentinel,
    Object? activeHostStream = _sentinel,
    Object? joinedStream = _sentinel,
    List<RtmpDestination>? rtmpDestinations,
    bool? isLoading,
    Object? errorMessage = _sentinel,
    Object? infoMessage = _sentinel,
  }) {
    return LiveStudioState(
      streams: streams ?? this.streams,
      createdStream: identical(createdStream, _sentinel)
          ? this.createdStream
          : createdStream as LiveStream?,
      activeHostStream: identical(activeHostStream, _sentinel)
          ? this.activeHostStream
          : activeHostStream as LiveStream?,
      joinedStream: identical(joinedStream, _sentinel)
          ? this.joinedStream
          : joinedStream as LiveStream?,
      rtmpDestinations: rtmpDestinations ?? this.rtmpDestinations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      infoMessage: identical(infoMessage, _sentinel)
          ? this.infoMessage
          : infoMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    streams,
    createdStream,
    activeHostStream,
    joinedStream,
    rtmpDestinations,
    isLoading,
    errorMessage,
    infoMessage,
  ];
}

const _sentinel = Object();

class LiveInitial extends LiveStudioState {
  const LiveInitial();
}

class LiveLoading extends LiveStreamState {}

class LiveListLoaded extends LiveStreamState {
  const LiveListLoaded(this.streams);
  final List<LiveStream> streams;
  @override
  List<Object?> get props => [streams];
}

class LiveCreated extends LiveStreamState {
  const LiveCreated(this.stream);
  final LiveStream stream;
  @override
  List<Object?> get props => [stream];
}

class LiveStarted extends LiveStreamState {
  const LiveStarted(this.stream, {this.rtmpDestinations = const []});
  final LiveStream stream;
  final List<RtmpDestination> rtmpDestinations;
  @override
  List<Object?> get props => [stream, rtmpDestinations];
}

class AudienceJoined extends LiveStreamState {
  const AudienceJoined(this.stream);
  final LiveStream stream;
  @override
  List<Object?> get props => [stream];
}

class RtmpConnected extends LiveStreamState {
  const RtmpConnected(this.destinations);
  final List<RtmpDestination> destinations;
  @override
  List<Object?> get props => [destinations];
}

class RtmpFailed extends LiveStreamState {
  const RtmpFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class LiveEnded extends LiveStreamState {}

class LiveError extends LiveStreamState {
  const LiveError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class LiveStreamBloc extends Bloc<LiveStreamEvent, LiveStreamState> {
  LiveStreamBloc(this._streams, this._tokens, this._agora, this._analytics)
    : super(const LiveInitial()) {
    on<WatchLiveStreams>(_watch);
    on<_LiveStreamsUpdated>(_streamsUpdated);
    on<_LiveStreamsFailed>(_streamsFailed);
    on<CreateLive>(_create);
    on<StartLive>(_start);
    on<JoinLive>(_join);
    on<RejoinHostLive>(_rejoinHost);
    on<LeaveLive>(_leave);
    on<LeaveHostRoom>(_leaveHostRoom);
    on<HostControlsChanged>(_hostControlsChanged);
    on<EndLive>(_end);
    on<DeleteLive>(_delete);
  }

  final ILiveStreamRepository _streams;
  final ITokenRepository _tokens;
  final IAgoraService _agora;
  final IAnalyticsRepository _analytics;
  StreamSubscription<List<LiveStream>>? _subscription;

  LiveStudioState get _studioState {
    final current = state;
    return current is LiveStudioState ? current : const LiveStudioState();
  }

  Future<T> _withTimeout<T>(Future<T> future, String action) {
    return future.timeout(
      const Duration(seconds: 18),
      onTimeout: () => throw TimeoutException(
        '$action timed out. Check network, Firebase rules, and Agora token.',
      ),
    );
  }

  void _streamsUpdated(
    _LiveStreamsUpdated event,
    Emitter<LiveStreamState> emit,
  ) {
    final current = _studioState;
    final liveById = {
      for (final stream in event.streams) stream.streamId: stream,
    };
    final activeHostStream = current.activeHostStream == null
        ? null
        : liveById[current.activeHostStream!.streamId];
    final joinedStream = current.joinedStream == null
        ? null
        : liveById[current.joinedStream!.streamId];
    final leftByRemoteEnd =
        current.joinedStream != null &&
        joinedStream == null &&
        !_studioState.isLoading;
    emit(
      current.copyWith(
        streams: event.streams,
        activeHostStream: activeHostStream,
        joinedStream: joinedStream,
        errorMessage: null,
        infoMessage: leftByRemoteEnd ? 'Live ended by host.' : null,
      ),
    );
  }

  void _streamsFailed(_LiveStreamsFailed event, Emitter<LiveStreamState> emit) {
    emit(_studioState.copyWith(errorMessage: event.message, isLoading: false));
  }

  Future<void> _watch(
    WatchLiveStreams event,
    Emitter<LiveStreamState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _streams.watchActiveStreams().listen(
      (streams) => add(_LiveStreamsUpdated(streams)),
      onError: (Object error) => add(_LiveStreamsFailed(error.toString())),
    );
  }

  Future<void> _create(CreateLive event, Emitter<LiveStreamState> emit) async {
    if (event.hostRole != 'admin') {
      emit(_studioState.copyWith(errorMessage: 'Only admin can create live.'));
      return;
    }
    if (event.title.trim().isEmpty) {
      emit(_studioState.copyWith(errorMessage: 'Live title is required.'));
      return;
    }
    emit(_studioState.copyWith(isLoading: true, errorMessage: null));
    try {
      final stream = await _streams.createLive(
        hostId: event.hostId,
        title: event.title,
        description: event.description,
      );
      emit(
        _studioState.copyWith(
          createdStream: stream,
          activeHostStream: null,
          isLoading: false,
          infoMessage: 'Live created. Press Start Live to go online.',
        ),
      );
    } catch (error) {
      emit(
        _studioState.copyWith(isLoading: false, errorMessage: error.toString()),
      );
    }
  }

  Future<void> _start(StartLive event, Emitter<LiveStreamState> emit) async {
    if (event.hostRole != 'admin') {
      emit(_studioState.copyWith(errorMessage: 'Only admin can start live.'));
      return;
    }
    emit(_studioState.copyWith(isLoading: true, errorMessage: null));
    try {
      await _withTimeout(_streams.startLive(event.stream), 'Start live');
      final liveStream = event.stream.copyWith(
        status: 'live',
        hostPresent: false,
        hostMicMuted: false,
        hostCameraOff: false,
        startedAt: DateTime.now(),
      );
      emit(
        _studioState.copyWith(
          createdStream: null,
          activeHostStream: liveStream,
          joinedStream: null,
          rtmpDestinations: const [],
          isLoading: false,
          infoMessage: 'Live room opened. Connecting video...',
        ),
      );
      final token = await _withTimeout(
        _tokens.tokenForChannel(channelName: event.stream.channelName),
        'Agora token',
      );
      await _withTimeout(
        _agora.joinAsHost(token: token, channelName: event.stream.channelName),
        'Host join',
      );
      await _withTimeout(
        _streams.updateHostState(event.stream.streamId, hostPresent: true),
        'Host presence update',
      );
      final connected = <RtmpDestination>[];
      for (final destination in event.destinations.where(
        (item) => item.enabled,
      )) {
        await _withTimeout(
          _agora.startRtmpPush(destination),
          'RTMP start ${destination.platformName}',
        );
        connected.add(destination);
      }
      final connectedStream = liveStream.copyWith(hostPresent: true);
      emit(
        _studioState.copyWith(
          createdStream: null,
          activeHostStream: connectedStream,
          joinedStream: null,
          rtmpDestinations: connected,
          isLoading: false,
          infoMessage: connected.isEmpty
              ? 'Live started on Agora. Add RTMP targets for cross-live.'
              : 'Live started and cross-live connected.',
        ),
      );
    } catch (error) {
      emit(
        _studioState.copyWith(
          activeHostStream: null,
          rtmpDestinations: const [],
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _join(JoinLive event, Emitter<LiveStreamState> emit) async {
    emit(
      _studioState.copyWith(
        joinedStream: event.stream,
        activeHostStream: null,
        isLoading: false,
        errorMessage: null,
        infoMessage: 'Opening live room...',
      ),
    );
    try {
      final token = await _withTimeout(
        _tokens.tokenForChannel(channelName: event.stream.channelName),
        'Agora token',
      );
      await _withTimeout(
        _agora.joinAsAudience(
          token: token,
          channelName: event.stream.channelName,
        ),
        'Audience join',
      );
      try {
        await _withTimeout(
          _streams.addViewer(event.stream.streamId),
          'Viewer count update',
        );
      } catch (_) {
        // Viewer count is useful, but it must not block the audience from joining.
      }
      emit(
        _studioState.copyWith(
          joinedStream: event.stream,
          activeHostStream: null,
          isLoading: false,
          infoMessage: 'Joined live stream.',
        ),
      );
    } catch (error) {
      emit(
        _studioState.copyWith(
          joinedStream: null,
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _rejoinHost(
    RejoinHostLive event,
    Emitter<LiveStreamState> emit,
  ) async {
    if (event.hostRole != 'admin') {
      emit(_studioState.copyWith(errorMessage: 'Only admin can rejoin host.'));
      return;
    }
    final rejoiningStream = event.stream.copyWith(hostPresent: false);
    emit(
      _studioState.copyWith(
        activeHostStream: rejoiningStream,
        joinedStream: null,
        isLoading: false,
        errorMessage: null,
        infoMessage: 'Opening host room...',
      ),
    );
    try {
      final token = await _withTimeout(
        _tokens.tokenForChannel(channelName: event.stream.channelName),
        'Agora token',
      );
      await _withTimeout(
        _agora.joinAsHost(token: token, channelName: event.stream.channelName),
        'Host rejoin',
      );
      await _withTimeout(
        _streams.updateHostState(event.stream.streamId, hostPresent: true),
        'Host presence update',
      );
      emit(
        _studioState.copyWith(
          activeHostStream: event.stream.copyWith(
            status: 'live',
            hostPresent: true,
          ),
          joinedStream: null,
          isLoading: false,
          infoMessage: 'Rejoined host room.',
        ),
      );
    } catch (error) {
      emit(
        _studioState.copyWith(
          activeHostStream: null,
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _leave(LeaveLive event, Emitter<LiveStreamState> emit) async {
    emit(
      _studioState.copyWith(
        joinedStream: null,
        isLoading: false,
        errorMessage: null,
      ),
    );
    Object? cleanupError;
    try {
      await _streams.removeViewer(event.stream.streamId);
    } catch (error) {
      // Best effort only; leaving Agora is the important user action.
      cleanupError ??= error;
    }
    try {
      await _agora.leaveChannel();
    } catch (error) {
      cleanupError ??= error;
    }
    emit(
      _studioState.copyWith(
        joinedStream: null,
        isLoading: false,
        errorMessage: cleanupError == null
            ? null
            : 'Left room locally. Cleanup warning: $cleanupError',
        infoMessage: cleanupError == null ? 'Left live stream.' : null,
      ),
    );
  }

  Future<void> _leaveHostRoom(
    LeaveHostRoom event,
    Emitter<LiveStreamState> emit,
  ) async {
    final current = _studioState;
    emit(
      current.copyWith(
        activeHostStream: null,
        rtmpDestinations: const [],
        isLoading: false,
        errorMessage: null,
        infoMessage: 'Host left the room. Live is still running.',
      ),
    );
    Object? cleanupError;
    try {
      await _withTimeout(
        _streams.updateHostState(
          event.stream.streamId,
          hostPresent: false,
          hostMicMuted: false,
          hostCameraOff: false,
        ),
        'Host presence update',
      );
    } catch (error) {
      cleanupError ??= error;
    }
    try {
      await _agora.leaveChannel();
      await _agora.destroy();
    } catch (error) {
      cleanupError ??= error;
    }
    if (cleanupError != null) {
      emit(
        _studioState.copyWith(
          errorMessage: 'Left room locally. Cleanup warning: $cleanupError',
          infoMessage: null,
        ),
      );
    }
  }

  Future<void> _hostControlsChanged(
    HostControlsChanged event,
    Emitter<LiveStreamState> emit,
  ) async {
    final current = _studioState;
    emit(
      current.copyWith(
        activeHostStream: current.activeHostStream?.copyWith(
          hostMicMuted: event.micMuted,
          hostCameraOff: event.cameraOff,
        ),
      ),
    );
    try {
      await _withTimeout(
        _streams.updateHostState(
          event.stream.streamId,
          hostMicMuted: event.micMuted,
          hostCameraOff: event.cameraOff,
        ),
        'Host controls update',
      );
    } catch (error) {
      emit(
        _studioState.copyWith(
          errorMessage: 'Control status sync failed: $error',
        ),
      );
    }
  }

  Future<void> _end(EndLive event, Emitter<LiveStreamState> emit) async {
    emit(
      _studioState.copyWith(
        createdStream: null,
        activeHostStream: null,
        joinedStream: null,
        rtmpDestinations: const [],
        isLoading: false,
        errorMessage: null,
      ),
    );
    Object? cleanupError;
    for (final destination in event.destinations.where(
      (item) => item.enabled,
    )) {
      try {
        await _agora.stopRtmpPush(destination.pushUrl);
      } catch (error) {
        cleanupError ??= error;
      }
    }
    try {
      await _agora.leaveChannel();
      await _agora.destroy();
    } catch (error) {
      cleanupError ??= error;
    }
    try {
      await _streams.endLive(event.stream);
    } catch (error) {
      cleanupError ??= error;
    }
    final startedAt = event.stream.startedAt ?? DateTime.now();
    try {
      await _analytics.saveAnalytics(
        StreamAnalytics(
          streamId: event.stream.streamId,
          duration: DateTime.now().difference(startedAt),
          peakViewers: event.stream.viewerCount,
          watchTime: Duration(minutes: event.stream.viewerCount * 3),
          rtmpSuccessRate: event.destinations.isEmpty ? 1 : 1,
        ),
      );
    } catch (error) {
      cleanupError ??= error;
    }
    emit(
      _studioState.copyWith(
        createdStream: null,
        activeHostStream: null,
        joinedStream: null,
        rtmpDestinations: const [],
        isLoading: false,
        errorMessage: cleanupError == null
            ? null
            : 'Live stopped locally. Firestore cleanup failed: $cleanupError',
        infoMessage: cleanupError == null
            ? 'Live ended and analytics saved.'
            : null,
      ),
    );
  }

  Future<void> _delete(DeleteLive event, Emitter<LiveStreamState> emit) async {
    emit(
      _studioState.copyWith(
        createdStream: null,
        activeHostStream: null,
        joinedStream: null,
        rtmpDestinations: const [],
        isLoading: false,
        errorMessage: null,
      ),
    );
    Object? cleanupError;
    for (final destination in event.destinations.where(
      (item) => item.enabled,
    )) {
      try {
        await _agora.stopRtmpPush(destination.pushUrl);
      } catch (error) {
        cleanupError ??= error;
      }
    }
    try {
      await _agora.leaveChannel();
      await _agora.destroy();
    } catch (error) {
      cleanupError ??= error;
    }
    final startedAt = event.stream.startedAt ?? DateTime.now();
    try {
      await _analytics.saveAnalytics(
        StreamAnalytics(
          streamId: event.stream.streamId,
          duration: DateTime.now().difference(startedAt),
          peakViewers: event.stream.viewerCount,
          watchTime: Duration(minutes: event.stream.viewerCount * 3),
          rtmpSuccessRate: event.destinations.isEmpty ? 1 : 1,
        ),
      );
    } catch (error) {
      cleanupError ??= error;
    }
    try {
      await _streams.deleteLive(event.stream);
    } catch (error) {
      cleanupError ??= error;
    }
    emit(
      _studioState.copyWith(
        createdStream: null,
        activeHostStream: null,
        joinedStream: null,
        rtmpDestinations: const [],
        isLoading: false,
        errorMessage: cleanupError == null
            ? null
            : 'Meeting stopped locally. Firestore delete failed: $cleanupError',
        infoMessage: cleanupError == null ? 'Live meeting deleted.' : null,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
