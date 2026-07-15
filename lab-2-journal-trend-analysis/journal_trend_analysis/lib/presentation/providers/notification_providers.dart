import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/notification_service.dart';

final notificationServiceProvider = Provider(
  (_) => NotificationService.instance,
);
