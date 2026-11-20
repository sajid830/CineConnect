import 'package:material_ui/material_ui.dart';
import 'chat_page.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const ChatPage(),
    );
  }
}