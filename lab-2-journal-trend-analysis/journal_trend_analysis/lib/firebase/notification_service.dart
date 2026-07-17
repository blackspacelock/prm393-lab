import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';

const _messagesKey = 'fcm_messages';
const notificationTopic = 'journaltrend_updates';

class ReceivedNotification {
  const ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toIso8601String(),
  };

  factory ReceivedNotification.fromJson(Map<String, dynamic> json) =>
      ReceivedNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
      );
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final _updates = StreamController<List<ReceivedNotification>>.broadcast();
  List<ReceivedNotification> _messages = [];

  List<ReceivedNotification> get messages => List.unmodifiable(_messages);
  Stream<List<ReceivedNotification>> get updates => _updates.stream;

  Future<void> initialize() async {
    _messages = await _readMessages();
    FirebaseMessaging.onMessage.listen(_receive);
    FirebaseMessaging.onMessageOpenedApp.listen(_receive);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) await _receive(initialMessage);
  }

  Future<void> enable() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError('Notification permission was denied.');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var attempt = 0; attempt < 20; attempt++) {
        if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (await FirebaseMessaging.instance.getAPNSToken() == null) {
        throw StateError('APNs token is not available. Check iOS push setup.');
      }
    }
    await FirebaseMessaging.instance.subscribeToTopic(notificationTopic);
  }

  Future<void> _receive(RemoteMessage message) async {
    await saveMessage(message);
    _messages = await _readMessages();
    _updates.add(messages);
  }

  static Future<void> saveMessage(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final messages = await _readMessages();
    final id = message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
    if (messages.any((item) => item.id == id)) return;

    final item = ReceivedNotification(
      id: id,
      title: message.notification?.title ??
          message.data['title']?.toString() ??
          'Research update',
      body: message.notification?.body ??
          message.data['body']?.toString() ??
          '',
      receivedAt: message.sentTime ?? DateTime.now(),
    );
    // ponytail: retain 50 local messages; use Firestore if cross-device history is required.
    final encoded = [item, ...messages]
        .take(50)
        .map((value) => jsonEncode(value.toJson()))
        .toList();
    await prefs.setStringList(_messagesKey, encoded);
  }

  static Future<List<ReceivedNotification>> _readMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <ReceivedNotification>[];
    for (final value in prefs.getStringList(_messagesKey) ?? const []) {
      try {
        result.add(
          ReceivedNotification.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Ignore a corrupt local entry instead of losing the valid history.
      }
    }
    return result;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.saveMessage(message);
}
