import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/agora_config.dart';
import '../errors/failures.dart';

abstract class IAgoraConfigRepository {
  Stream<AgoraConfig> watchConfig();
  Future<AgoraConfig> currentConfig();
  Future<void> updateConfig(AgoraConfig config, {required String updatedBy});
}

class FirestoreAgoraConfigRepository implements IAgoraConfigRepository {
  FirestoreAgoraConfigRepository(this._firestore);

  static const _docPath = 'app_config/agora';

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore.doc(_docPath);

  @override
  Stream<AgoraConfig> watchConfig() {
    return _doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? AgoraConfig.defaults() : AgoraConfig.fromMap(data);
    });
  }

  @override
  Future<AgoraConfig> currentConfig() async {
    try {
      final snapshot = await _doc.get();
      final data = snapshot.data();
      return data == null ? AgoraConfig.defaults() : AgoraConfig.fromMap(data);
    } on FirebaseException {
      return AgoraConfig.defaults();
    }
  }

  @override
  Future<void> updateConfig(
    AgoraConfig config, {
    required String updatedBy,
  }) async {
    final live = await _firestore
        .collection('live_streams')
        .where('status', isEqualTo: 'live')
        .limit(1)
        .get();
    if (live.docs.isNotEmpty) {
      throw FirebaseFailure(
        'Agora config abhi change nahi kar sakte. Ek host live chal raha hai.',
      );
    }
    try {
      await _doc.set(
        config.toMap(updatedBy: updatedBy),
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw FirebaseFailure(
          'Only super admin can update Agora config. Firestore rules deploy karo.',
          error,
        );
      }
      throw FirebaseFailure('Unable to update Agora config.', error);
    }
  }
}
