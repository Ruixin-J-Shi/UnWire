class Message {
  final String content;
  final String sender;
  final DateTime timestamp;

  Message({
    required this.content,
    required this.sender,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender': sender,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['content'],
      sender: json['sender'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
