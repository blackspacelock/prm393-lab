import 'package:flutter/material.dart';
import 'package:fu_grading/widgets/chat_widget.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ollama Chat'),
      ),
      body: ChatWidget(),
    );
  }
}
