// lib/combined_chat_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';                     // For jsonEncode/Decode
import 'package:http/http.dart' as http;    // For API calls
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For API key

// --- 1. Model Definition ---
class ChatMessage {
  final String text;
  final bool isUserMessage;
  ChatMessage({required this.text, required this.isUserMessage});
}

// --- 2. Service Definition ---
class GeminiService {
  final String? _apiKey = dotenv.env['GEMINI_API_KEY'];
  final String _model = "gemini-1.5-flash";
  final String _apiVersion = "v1beta";

  Future<String?> generateText(String prompt, List<ChatMessage> history) async {
    if (_apiKey == null) return "Error: API Key not configured.";

    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/$_apiVersion/models/$_model:generateContent?key=$_apiKey"
    );

    final apiHistory = history.map((msg) => {
      "role": msg.isUserMessage ? "user" : "model",
      "parts": [{"text": msg.text}]
    }).toList();

    final contentPayload = [
      ...apiHistory,
      {"role": "user", "parts": [{"text": prompt}]}
    ];

    final body = json.encode({"contents": contentPayload});

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final candidates = data['candidates'];
      if (candidates != null && candidates.isNotEmpty) {
        return candidates[0]['content']['parts'][0]['text'];
      }
      return "";
    } else {
      return "Error: ${response.statusCode}";
    }
  }
}

// --- 3. UI Widget Definition ---
class CombinedChatScreen extends StatefulWidget {
  @override
  _CombinedChatScreenState createState() => _CombinedChatScreenState();
}

class _CombinedChatScreenState extends State<CombinedChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // welcome text shown at top
  final String _welcomeText =
      'مرحباً! أنا نمو، مساعدك الذكي في الاستثمار. '
      'أنا هنا لأجيب على أي سؤال حول الاستثمار أو السوق. كيف يمكنني مساعدتك اليوم؟';

  @override
  void initState() {
    super.initState();
    // Add the welcome message first
    _messages.add(ChatMessage(text: _welcomeText, isUserMessage: false));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,  // entire screen RTL
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:  Color(0xFF609966),
          // force the back button on the left and pointing left
          leading: Directionality(
            textDirection: TextDirection.ltr,
            child: BackButton(color: Colors.white),
          ),
          title: Text('نمو شات بوت', style: TextStyle(color: Colors.white)),
          centerTitle: true,
        ),
        backgroundColor: Colors.green[50],
        body: Column(
          children: [
            // welcome bubble
      //      Padding(
        //      padding: const EdgeInsets.all(8.0),
          //    child: MessageBubble(
            //    text: _welcomeText,
              //  isUserMessage: false,
             // ),
           // ),
/*  Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: _messages.length - 1,
                itemBuilder: (context, i) {
                  final msg = _messages[i + 1];
                  return MessageBubble(
                    text: msg.text,
                    isUserMessage: msg.isUserMessage,
                  );
                },
              ),
            ),*/
            // chat history
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  return MessageBubble(
                    text: msg.text,
                    isUserMessage: msg.isUserMessage,
                  );
                },
              ),
            ),

            // loading indicator
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(color:  Color(0xFF609966)),
              ),

            // user input row
            _buildUserInput(),
          ],
        ),
      ),
    );
  }
  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color:  Color(0xFF609966)),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [

              IconButton(
                icon: Icon(Icons.send, color:  Color(0xFF609966)),
                onPressed: _isLoading ? null : _sendMessage,
              ),

              Expanded(
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: "اكتب رسالتك هنا...",
                    hintTextDirection: TextDirection.rtl,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUserMessage: true));
      _isLoading = true;
    });
    _controller.clear();
    final response = await _geminiService.generateText(text, List.from(_messages));
    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        text: response ?? 'خطأ في استرجاع الرد',
        isUserMessage: false,
      ));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// --- 4. Message Bubble Widget Definition ---
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUserMessage;

  const MessageBubble({
    Key? key,
    required this.text,
    required this.isUserMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isUserMessage ? Colors.green[100] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color:  Color(0xFF609966)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUserMessage ?  Color(0xFF609966): Colors.black,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
