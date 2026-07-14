import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteLimits {
  const RemoteLimits({
    required this.maxJournals,
    required this.maxKeywords,
    required this.updated,
  });

  final int maxJournals;
  final int maxKeywords;
  final bool updated;

  factory RemoteLimits.fromValues({
    required int maxJournals,
    required int maxKeywords,
    bool updated = false,
  }) => RemoteLimits(
    maxJournals: maxJournals.clamp(1, 100).toInt(),
    maxKeywords: maxKeywords.clamp(1, 100).toInt(),
    updated: updated,
  );
}

class RemoteConfigService {
  RemoteConfigService(this._config);

  final FirebaseRemoteConfig _config;

  Future<RemoteLimits> fetch() async {
    await _config.setDefaults(const {
      'max_journals_displayed': 10,
      'max_keywords_displayed': 10,
    });
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: Duration.zero,
      ),
    );
    final updated = await _config.fetchAndActivate();
    return RemoteLimits.fromValues(
      maxJournals: _config.getInt('max_journals_displayed'),
      maxKeywords: _config.getInt('max_keywords_displayed'),
      updated: updated,
    );
  }
}
