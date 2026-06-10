import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/agora_config_repository.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/models/live_stream.dart';
import '../../../shared/models/rtmp_destination.dart';
import '../domain/live_stream_repository.dart';

class FirestoreLiveStreamRepository implements ILiveStreamRepository {
  FirestoreLiveStreamRepository(this._firestore, this._agoraConfig);

  final FirebaseFirestore _firestore;
  final IAgoraConfigRepository _agoraConfig;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _streams =>
      _firestore.collection('live_streams');

  @override
  Stream<List<LiveStream>> watchActiveStreams() {
    return _streams.where('status', isEqualTo: 'live').snapshots().map((
      snapshot,
    ) {
      final streams = snapshot.docs
          .map((doc) => LiveStream.fromMap(doc.data()))
          .toList();
      streams.sort((a, b) {
        final bStarted = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final aStarted = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bStarted.compareTo(aStarted);
      });
      return streams;
    });
  }

  @override
  Future<LiveStream> createLive({
    required String hostId,
    required String title,
    required String description,
    String thumbnailUrl = '',
  }) async {
    try {
      final config = await _agoraConfig.currentConfig();
      final stream = LiveStream(
        streamId: _uuid.v4(),
        hostId: hostId,
        title: title,
        description: description,
        channelName: config.channelName,
        status: 'created',
        viewerCount: 0,
        thumbnailUrl: thumbnailUrl,
      );
      await _streams.doc(stream.streamId).set(stream.toMap());
      await writeEvent(stream.streamId, 'created', 'Live stream created.');
      return stream;
    } on FirebaseException catch (error) {
      throw _failure('Unable to create live stream.', error);
    } catch (error) {
      throw FirebaseFailure('Unable to create live stream.', error);
    }
  }

  @override
  Future<void> startLive(LiveStream stream) async {
    try {
      await _streams.doc(stream.streamId).update({
        'status': 'live',
        'startedAt': FieldValue.serverTimestamp(),
        'hostPresent': false,
        'hostMicMuted': false,
        'hostCameraOff': false,
      });
      await writeEvent(stream.streamId, 'started', 'Live stream started.');
    } on FirebaseException catch (error) {
      throw _failure('Unable to start live stream.', error);
    }
  }

  @override
  Future<void> endLive(LiveStream stream) async {
    try {
      await _streams.doc(stream.streamId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'hostPresent': false,
      });
      await writeEvent(stream.streamId, 'ended', 'Live stream ended.');
    } on FirebaseException catch (error) {
      throw _failure('Unable to end live stream.', error);
    }
  }

  @override
  Future<void> deleteLive(LiveStream stream) async {
    try {
      try {
        await writeEvent(stream.streamId, 'deleted', 'Live stream deleted.');
      } catch (_) {
        // Deleting the meeting is more important than preserving the audit event.
      }
      await _streams.doc(stream.streamId).delete();
    } on FirebaseException catch (error) {
      throw _failure('Unable to delete live stream.', error);
    }
  }

  @override
  Future<void> updateHostState(
    String streamId, {
    bool? hostPresent,
    bool? hostMicMuted,
    bool? hostCameraOff,
  }) async {
    final data = <String, Object?>{};
    if (hostPresent != null) data['hostPresent'] = hostPresent;
    if (hostMicMuted != null) data['hostMicMuted'] = hostMicMuted;
    if (hostCameraOff != null) data['hostCameraOff'] = hostCameraOff;
    if (data.isEmpty) return;
    try {
      await _streams.doc(streamId).update(data);
    } on FirebaseException catch (error) {
      throw _failure('Unable to update host state.', error);
    }
  }

  @override
  Future<void> addViewer(String streamId) =>
      _streams.doc(streamId).update({'viewerCount': FieldValue.increment(1)});

  @override
  Future<void> removeViewer(String streamId) =>
      _streams.doc(streamId).update({'viewerCount': FieldValue.increment(-1)});

  @override
  Future<void> writeEvent(String streamId, String type, String message) {
    return _firestore.collection('stream_events').add({
      'streamId': streamId,
      'type': type,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<RtmpDestination>> getEnabledDestinations() async {
    final snapshot = await _firestore
        .collection('rtmp_destinations')
        .where('enabled', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => RtmpDestination.fromMap(doc.data()))
        .toList();
  }

  FirebaseFailure _failure(String message, FirebaseException error) {
    if (error.code == 'permission-denied') {
      return FirebaseFailure(
        '$message Firestore permission denied. Login first and deploy the provided firestore.rules.',
        error,
      );
    }
    return FirebaseFailure(message, error);
  }
}
