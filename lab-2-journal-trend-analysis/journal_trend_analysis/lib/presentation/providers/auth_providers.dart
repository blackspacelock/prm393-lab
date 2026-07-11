import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/analytics_service.dart';

final authServiceProvider = Provider(
  (_) => AuthService(FirebaseAuth.instance, analyticsService),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges,
);
