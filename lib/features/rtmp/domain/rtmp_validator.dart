import '../../../shared/models/rtmp_destination.dart';

class RtmpValidator {
  const RtmpValidator();

  String validate(RtmpDestination destination) {
    if (destination.rtmpUrl.trim().isEmpty) {
      return 'RTMP URL is required.';
    }
    if (!destination.hasValidUrl) {
      return 'RTMP URL must start with rtmp://';
    }
    if (destination.streamKey.trim().isEmpty) {
      return 'Stream key is required.';
    }
    return '';
  }
}
