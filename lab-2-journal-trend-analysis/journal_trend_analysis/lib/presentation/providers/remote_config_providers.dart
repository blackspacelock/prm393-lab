import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/remote_config_service.dart';

final remoteConfigServiceProvider = Provider(
  (_) => RemoteConfigService(FirebaseRemoteConfig.instance),
);

final remoteLimitsProvider = StreamProvider(
  (ref) => ref.watch(remoteConfigServiceProvider).watch(),
);
