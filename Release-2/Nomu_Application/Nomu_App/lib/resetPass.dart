import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String oobCode; // الكود اللي يجي من رابط إعادة التعيين

  const ResetPasswordPage({required this.email, required this.oobCode, Key? key}) : super(key: key);

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;
  bool _isLoading = false;

  void _showDialog(String title, String message, {bool success = false}) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('حسناً')),
              if (success)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // العودة للصفحة السابقة
                  },
                  child: Text('الرجوع لتسجيل الدخول'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى تعبئة جميع الحقول';
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _errorMessage = 'كلمة المرور وتأكيدها غير متطابقين';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // أكمل إعادة التعيين باستخدام Firebase
      await _auth.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: password,
      );

      _showDialog('نجاح', 'تم إعادة تعيين كلمة المرور بنجاح', success: true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'حدث خطأ غير معروف';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Image.asset('assets/logo.png', height: 80)),
              SizedBox(height: 20),
              Text('إعادة تعيين كلمة المرور', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('أدخل كلمة المرور الجديدة وتأكيدها:', style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),

              // كلمة المرور
              TextField(
                controller: _passwordController,
                obscureText: true,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              SizedBox(height: 20),

              // تأكيد كلمة المرور
              TextField(
                controller: _confirmController,
                obscureText: true,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: 20),

              // رسالة خطأ
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.right),
                SizedBox(height: 20),
              ],

              // زر إعادة التعيين
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF609966),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('إعادة التعيين', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
