import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/auth_service.dart';

final authServiceProvider = Provider(
  (_) => AuthService(FirebaseAuth.instance, FirebaseAnalytics.instance),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges,
);
