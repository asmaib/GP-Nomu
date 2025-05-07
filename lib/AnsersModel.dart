class MessageModel {
  final bool isUser;
  final String message;
  final DateTime time;

  MessageModel({
    required this.isUser,
    required this.message,
    required this.time,
  });
}
