// lib/combined_chat_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// --- 1. Model Definition ---
class ChatMessage {
  final String text;
  final bool isUserMessage;
  ChatMessage({required this.text, required this.isUserMessage});
}

// --- 2. Service Definition ---
class GeminiService {
  final String? _apiKey = dotenv.env['GEMINI_API_KEY'];
  final String _apiVersion = "v1beta";
  
  Future<String?> generateText(String prompt, List<ChatMessage> history) async {
    // Debug: Check API key
    if (_apiKey == null || _apiKey!.isEmpty) {
      print('❌ API Key is missing!');
      return "خطأ: مفتاح API غير موجود. تأكد من ملف .env";
    }
    
    print('✅ API Key found: ${_apiKey!.substring(0, 10)}...');

    // Try different model endpoints (updated to latest models)
    final modelsToTry = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-flash-latest',
      'gemini-pro-latest',
      'gemini-2.5-pro',
    ];
    
    for (var model in modelsToTry) {
      final url = Uri.parse(
          "https://generativelanguage.googleapis.com/$_apiVersion/models/$model:generateContent?key=$_apiKey"
      );
      
      print('📡 Trying model: $model');

      // System prompt to specialize the chatbot
      final String systemPrompt = '''
أنت "نمو"، مساعد ذكي متخصص في المجال المالي والاستثماري فقط.

مهامك:
- الإجابة على الأسئلة المتعلقة بالاستثمار، الأسهم، السندات، الصناديق الاستثمارية، العملات الرقمية
- شرح المفاهيم المالية مثل: التحليل المالي، التنويع، إدارة المخاطر، العوائد
- تقديم نصائح عامة حول الادخار والتخطيط المالي
- شرح أساسيات سوق الأسهم السعودي والعالمي
- الإجابة باللغة العربية بأسلوب واضح ومبسط

القواعد الصارمة:
- لا تجب على أي سؤال خارج المجال المالي والاستثماري
- إذا سألك المستخدم عن موضوع غير مالي (طبخ، رياضة، برمجة، إلخ)، قل:
  "عذراً، أنا متخصص فقط في الإجابة على الأسئلة المالية والاستثمارية. هل لديك أي سؤال عن الاستثمار أو الأسهم؟"
- لا تقدم نصائح استثمارية شخصية محددة (مثل "اشتري سهم معين")
- دائماً ذكّر المستخدم بأهمية استشارة مستشار مالي مرخص قبل اتخاذ قرارات استثمارية

أسلوبك:
- ودود ومحترف
- واضح ومباشر
- تعليمي وتثقيفي
''';

      // Build history for API
      final apiHistory = <Map<String, dynamic>>[];
      
      // Add system instruction as first message
      apiHistory.add({
        "role": "user",
        "parts": [{"text": systemPrompt}]
      });
      apiHistory.add({
        "role": "model",
        "parts": [{"text": "فهمت تماماً. أنا نمو، مساعدك المتخصص في الأسئلة المالية والاستثمارية فقط. جاهز للإجابة على أسئلتك!"}]
      });

      // Add conversation history
      for (var msg in history) {
        apiHistory.add({
          "role": msg.isUserMessage ? "user" : "model",
          "parts": [{"text": msg.text}]
        });
      }

      // Add current prompt
      apiHistory.add({
        "role": "user",
        "parts": [{"text": prompt}]
      });

      final body = json.encode({"contents": apiHistory});

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(Duration(seconds: 30));

        print('📥 Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final candidates = data['candidates'];
          if (candidates != null && candidates.isNotEmpty) {
            print('✅ Success with model: $model');
            return candidates[0]['content']['parts'][0]['text'];
          }
        } else if (response.statusCode == 404) {
          print('⚠️ Model $model not available, trying next...');
          continue; // Try next model
        } else {
          print('❌ Error response: ${response.body}');
          return "خطأ ${response.statusCode}: الرجاء المحاولة مرة أخرى";
        }
      } catch (e) {
        print('❌ Exception with $model: $e');
        continue; // Try next model
      }
    }
    
    // If all models failed
    return "عذراً، لم أتمكن من الاتصال. تأكد من:\n"
        "1. مفتاح API صحيح\n"
        "2. تفعيل Gemini API في Google Cloud\n"
        "3. الاتصال بالإنترنت";
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

  // Welcome message
  final String _welcomeText =
      'مرحباً! أنا نمو، مساعدك الذكي المتخصص في الاستثمار والأسواق المالية. 📈\n\n'
       ;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(text: _welcomeText, isUserMessage: false));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF609966),
          leading: Directionality(
            textDirection: TextDirection.ltr,
            child: BackButton(color: Colors.white),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text('نمو - مساعدك المالي', 
                style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          centerTitle: true,
        ),
        backgroundColor: Colors.green[50],
        body: Column(
          children: [
            // Chat history
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

            // Loading indicator
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Color(0xFF609966),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('نمو يفكر...', 
                      style: TextStyle(color: Color(0xFF609966))),
                  ],
                ),
              ),

            // User input
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
          border: Border.all(color: Color(0xFF609966), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.send, color: Color(0xFF609966)),
                onPressed: _isLoading ? null : _sendMessage,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl, // إضافة اتجاه النص
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: "اسأل نمو عن أي شيء يتعلق بالاستثمار...",
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: TextStyle(color: Colors.grey[400]),
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
        text: response ?? 'عذراً، حدث خطأ. الرجاء المحاولة مرة أخرى.',
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

// --- 4. Message Bubble Widget ---
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
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUserMessage ? Color(0xFF609966) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isUserMessage ? Radius.circular(20) : Radius.circular(4),
            bottomRight: isUserMessage ? Radius.circular(4) : Radius.circular(20),
          ),
          border: Border.all(
            color: isUserMessage ? Color(0xFF609966) : Colors.grey[300]!,
            width: isUserMessage ? 0 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: isUserMessage
            ? Text(
                text,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              )
            : Directionality(
                textDirection: TextDirection.rtl,
                child: MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    listBullet: TextStyle(color: Colors.black87),
                    textAlign: WrapAlignment.start,
                  ),
                  selectable: false,
                ),
              ),
      ),
    );
  }
}