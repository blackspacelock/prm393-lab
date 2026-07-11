import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/notification_service.dart';

final notificationServiceProvider = Provider(
  (_) => NotificationService.instance,
);

final notificationHistoryProvider =
    StreamProvider<List<ReceivedNotification>>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  yield service.messages;
  yield* service.updates;
});
