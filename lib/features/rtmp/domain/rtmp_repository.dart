import '../../../shared/models/rtmp_destination.dart';

abstract class IRtmpRepository {
  Stream<List<RtmpDestination>> watchDestinations();
  Future<void> saveDestination(RtmpDestination destination);
  String validate(RtmpDestination destination);
}
