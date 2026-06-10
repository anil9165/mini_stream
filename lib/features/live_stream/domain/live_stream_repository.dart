import '../../../shared/models/live_stream.dart';
import '../../../shared/models/rtmp_destination.dart';

abstract class ILiveStreamRepository {
  Stream<List<LiveStream>> watchActiveStreams();
  Future<LiveStream> createLive({
    required String hostId,
    required String title,
    required String description,
    String thumbnailUrl,
  });
  Future<void> startLive(LiveStream stream);
  Future<void> endLive(LiveStream stream);
  Future<void> deleteLive(LiveStream stream);
  Future<void> updateHostState(
    String streamId, {
    bool? hostPresent,
    bool? hostMicMuted,
    bool? hostCameraOff,
  });
  Future<void> addViewer(String streamId);
  Future<void> removeViewer(String streamId);
  Future<void> writeEvent(String streamId, String type, String message);
  Future<List<RtmpDestination>> getEnabledDestinations();
}
