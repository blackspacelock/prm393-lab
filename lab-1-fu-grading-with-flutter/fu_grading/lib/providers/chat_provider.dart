import 'package:flutter/material.dart';
import '../services/ollama_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatProvider with ChangeNotifier {
  final OllamaService _ollamaService = OllamaService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text) async {
    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
    notifyListeners();

    final stream = _ollamaService.generate(text);
    String response = '';
    _messages.add(ChatMessage(text: '', isUser: false));

    stream.listen(
      (chunk) {
        response += chunk;
        _messages.last = ChatMessage(text: response, isUser: false);
        notifyListeners();
      },
      onDone: () {
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _messages.last = ChatMessage(text: 'Error: $error', isUser: false);
        _isLoading = false;
        notifyListeners();
      },
    );
  }
}
