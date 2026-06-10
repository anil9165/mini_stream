import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/stream_analytics.dart';
import '../domain/analytics_repository.dart';

class FirestoreAnalyticsRepository implements IAnalyticsRepository {
  FirestoreAnalyticsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> saveAnalytics(StreamAnalytics analytics) {
    return _firestore
        .collection('analytics')
        .doc(analytics.streamId)
        .set(analytics.toMap());
  }
}
