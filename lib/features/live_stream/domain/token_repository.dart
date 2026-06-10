import '../../../core/config/agora_config_repository.dart';

abstract class ITokenRepository {
  Future<String> tokenForChannel({required String channelName, int uid = 0});
}

class StaticTokenRepository implements ITokenRepository {
  StaticTokenRepository(this._config);

  final IAgoraConfigRepository _config;

  @override
  Future<String> tokenForChannel({
    required String channelName,
    int uid = 0,
  }) async {
    final config = await _config.currentConfig();
    return config.tempToken;
  }
}

class RestTokenRepository implements ITokenRepository {
  RestTokenRepository({required this.endpoint});

  final Uri endpoint;

  @override
  Future<String> tokenForChannel({required String channelName, int uid = 0}) {
    throw UnimplementedError(
      'Connect this to your backend token API: $endpoint',
    );
  }
}
