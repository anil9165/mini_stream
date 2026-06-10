import '../../../shared/models/stream_analytics.dart';

abstract class IAnalyticsRepository {
  Future<void> saveAnalytics(StreamAnalytics analytics);
}
