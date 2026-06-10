import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/models/rtmp_destination.dart';
import '../domain/rtmp_repository.dart';
import '../domain/rtmp_validator.dart';

class FirestoreRtmpRepository implements IRtmpRepository {
  FirestoreRtmpRepository(this._firestore);

  final FirebaseFirestore _firestore;
  final _validator = const RtmpValidator();

  @override
  Stream<List<RtmpDestination>> watchDestinations() {
    return _firestore
        .collection('rtmp_destinations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RtmpDestination.fromMap(doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> saveDestination(RtmpDestination destination) {
    return _firestore
        .collection('rtmp_destinations')
        .doc(destination.destinationId)
        .set(destination.toMap(), SetOptions(merge: true))
        .onError<FirebaseException>((error, stackTrace) {
          if (error.code == 'permission-denied') {
            throw FirebaseFailure(
              'Firestore permission denied. Login first and deploy firestore.rules.',
              error,
            );
          }
          throw FirebaseFailure('Unable to save RTMP destination.', error);
        });
  }

  @override
  String validate(RtmpDestination destination) =>
      _validator.validate(destination);
}
