import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart'; 
import 'home_page.dart'; 

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

void _showMessageDialog(String title, String message) {
  showDialog(
    context: context,
    builder: (context) {
      return Directionality(  // Ensure RTL text direction for Arabic
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),  // Rounded corners
          ),
          backgroundColor: Color.fromARGB(255, 157, 192, 139),  // Custom background color
          title: Text(
            title,
            textAlign: TextAlign.right,  // Align text to the right for RTL
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: Text(
            message,
            textAlign: TextAlign.right,  // Align text to the right for RTL
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),  // Dismiss the dialog
              child: Text(
                'حسناً',
                style: TextStyle(color: Colors.black),  // Button text in black
              ),
            ),
          ],
        ),
      );
    },
  );
}


// Login function that redirects the user to the home page upon success
  void _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessageDialog('خطأ', 'يرجى إدخال البريد وكلمة المرور');
      return;
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
// Redirect the user to the home page after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } on FirebaseAuthException catch (_) {
      _showMessageDialog(
        'خطأ',
        'عفواً، البيانات المدخلة غير صحيحة. يرجى التأكد من صحة البريد الإلكتروني وكلمة المرور والمحاولة مرة أخرى.',
      );
    } catch (_) {
      _showMessageDialog(
        'خطأ',
        'عفواً، حدث خطأ أثناء عملية تسجيل الدخول. يرجى المحاولة مرة أخرى.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60),
              Align(
                alignment: Alignment.center,
                child: Image.asset('assets/logo.png', height: 80),
              ),
              SizedBox(height: 20),
              _buildToggleButtons(context, isSignup: false),
              SizedBox(height: 30),
              Text(
                'أهلاً بك مجددًا\nسجل البيانات التالية للدخول',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              _buildTextField(
                "الإيميل",
                "example@example.com",
                Icons.email,
                _emailController,
              ),
              _buildPasswordField(
                "كلمة المرور",
                Icons.lock,
                _passwordController,
              ),
              // When the user clicks on "Forgot Password," they are redirected to the password recovery page
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ForgotPasswordPage()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: "نسيت كلمة المرور؟ ",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        TextSpan(
                          text: "اضغط هنا",
                          style: TextStyle(color: Color(0xFF609966), fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _buildMainButton("تسجيل الدخول", _login),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignupPage()),
                  );
                },
                child: RichText(
                  text: TextSpan(
                    text: "يمكنك إنشاء حساب جديد عن طريق ",
                    style: TextStyle(color: Colors.black, fontSize: 16),
                    children: [
                      TextSpan(
                        text: "الضغط هنا",
                        style: TextStyle(color: Color(0xFF609966), fontSize: 16),
                      ),
                    ],
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

// Function to build a text input field
  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

// Function to build a password input field
  Widget _buildPasswordField(String label, IconData icon, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ),
    );
  }

// Function to build the main button
  Widget _buildMainButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF609966),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(text, style: TextStyle(fontSize: 18, color: Colors.white)),
      ),
    );
  }

// Function to build the toggle buttons between sign-up and login
  Widget _buildToggleButtons(BuildContext context, {required bool isSignup}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SignupPage()));
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isSignup ? Color(0xFF609966) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'إنشاء حساب',
                    style: TextStyle(color: isSignup ? Colors.white : Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: !isSignup ?Color(0xFF609966) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'تسجيل الدخول',
                    style: TextStyle(color: !isSignup ? Colors.white : Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
