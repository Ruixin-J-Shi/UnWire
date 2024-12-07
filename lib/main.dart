import 'package:flutter/material.dart';
import 'package:nearby_service/nearby_service.dart';
import 'utils/app_snack_bar.dart';
import 'chat_room.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nearby Group Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const NameEntryPage(),
    );
  }
}

class NameEntryPage extends StatefulWidget {
  const NameEntryPage({super.key});

  @override
  State<NameEntryPage> createState() => _NameEntryPageState();
}

class _NameEntryPageState extends State<NameEntryPage> {
  final TextEditingController _nameController = TextEditingController();

  void _startChat() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.show(context, title: 'Please enter a name.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoom(myName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Your Name'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Your Name'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startChat,
              child: const Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }
}
