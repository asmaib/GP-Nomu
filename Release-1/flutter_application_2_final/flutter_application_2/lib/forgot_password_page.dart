import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  bool _linkSent = false;
  String? _errorMessage; // State variable for inline error message

  // Helper: show pop-up dialog for success message
  void _showMessageDialog(String title, String message, {bool success = false}) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // Rounded corners
            ),
            backgroundColor: Color.fromARGB(255, 157, 192, 139), // Custom background color
            title: Text(
              title,
              textAlign: TextAlign.right, // Align text to the right for RTL
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            content: Text(
              message,
              textAlign: TextAlign.right, // Align text to the right for RTL
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            actions: [
              // "حسناً" button to just close the dialog
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text(
                  'حسناً',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              // "الرجوع لتسجيل الدخول" button (only appears on success)
              if (success)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    Navigator.of(context).pop(); // Return to login page
                  },
                  child: Text(
                    'الرجوع لتسجيل الدخول',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Send password reset link
  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال بريدك الإلكتروني';
      });
      return;
    }
    // Clear any previous error message
    setState(() {
      _errorMessage = null;
    });
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showMessageDialog(
        'نجاح',
        'إذا كان هناك حساب مسجل بهذا البريد الإلكتروني، فقد تم إرسال رابط لإعادة تعيين كلمة المرور',
        success: true, // Display the login button
      );
      setState(() {
        _linkSent = true;
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        setState(() {
          _errorMessage = 'يرجى إدخال بريد إلكتروني صحيح';
        });
      } else {
        setState(() {
          _errorMessage = 'حدث خطأ: ${e.message}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // Align everything to the right
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // "start" is right side in RTL
            children: [
              SizedBox(height: 60),

              // (Optional) Add a centered logo at the top
              Align(
                alignment: Alignment.center,
                child: Image.asset('assets/logo.png', height: 80),
              ),
              SizedBox(height: 20),

              Text(
                'إعادة تعيين كلمة المرور',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),

              Text(
                'أدخل بريدك الإلكتروني لإرسال رابط إعادة تعيين كلمة المرور:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),

              // Email text field
              TextField(
                controller: _emailController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'الإيميل',
                  hintText: 'example@example.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              SizedBox(height: 20),

              // Inline error message in red (if exists)
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.right,
                ),
                SizedBox(height: 20),
              ],

              // Send / Resend button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _sendResetLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF609966),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    _linkSent ? 'إعادة الإرسال' : 'إرسال الرابط',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Back to login link
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'الرجوع لصفحة تسجيل الدخول؟ ',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        TextSpan(
                          text: 'اضغط هنا',
                          style: TextStyle(color: Color(0xFF609966), fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
