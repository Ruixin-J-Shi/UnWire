import 'package:flutter/material.dart';
import 'package:nearby_service/nearby_service.dart';

class ChatRoom extends StatefulWidget {
  final String deviceName;
  final NearbyService nearbyService;
  final NearbyDeviceInfo receiverDeviceInfo; // Add the connected peer's info

  const ChatRoom({
    super.key,
    required this.deviceName,
    required this.nearbyService,
    required this.receiverDeviceInfo,
  });

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    widget.nearbyService.startCommunicationChannel(
      NearbyCommunicationChannelData(
        widget.receiverDeviceInfo.id, // Use receiver's ID
        messagesListener: NearbyServiceMessagesListener(
          onData: (message) {
            setState(() {
              _messages.add('Peer: ${message.content.byType(onTextRequest: (req) => req.value)}');
            });
          },
        ),
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      await widget.nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextRequest.create(value: message),
          receiver: widget.receiverDeviceInfo, // Use the receiver's info here
        ),
      );
      setState(() {
        _messages.add('You: $message');
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat Room - ${widget.deviceName}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(_messages[index]));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Enter your message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
