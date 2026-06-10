import 'package:flutter_test/flutter_test.dart';
import 'package:mini_live/features/rtmp/domain/rtmp_validator.dart';
import 'package:mini_live/shared/models/rtmp_destination.dart';

void main() {
  const validator = RtmpValidator();

  test('rejects empty RTMP URL', () {
    final result = validator.validate(
      const RtmpDestination(
        destinationId: '1',
        platformName: 'YouTube',
        rtmpUrl: '',
        streamKey: 'abc',
      ),
    );

    expect(result, 'RTMP URL is required.');
  });

  test('builds push URL from server and stream key', () {
    const destination = RtmpDestination(
      destinationId: '1',
      platformName: 'YouTube',
      rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2/',
      streamKey: 'secret-key',
    );

    expect(destination.pushUrl, 'rtmp://a.rtmp.youtube.com/live2/secret-key');
    expect(validator.validate(destination), isEmpty);
  });
}
