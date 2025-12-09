import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'home_page.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _generalError;

  String _validatePassword(String password) {
    List<String> errors = [];
    if (password.length < 12) {
      errors.add('يجب أن تكون كلمة المرور على الأقل 12 حرفاً');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('يجب أن تحتوي على حرف كبير واحد على الأقل');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('يجب أن تحتوي على حرف صغير واحد على الأقل');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('يجب أن تحتوي على رقم واحد على الأقل');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('يجب أن تحتوي على رمز خاص واحد على الأقل');
    }
    return errors.join('\n');
  }

  bool _isValidEmail(String email) {
    return RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _generalError = null;
    });

    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    bool hasError = false;

    if (username.isEmpty) {
      _usernameError = 'يرجى إدخال اسم المستخدم';
      hasError = true;
    } else if (username.length < 2 || username.length > 50) {
      _usernameError = 'يجب أن يكون الاسم بين 2 و50 حرفاً';
      hasError = true;
    }

    if (email.isEmpty) {
      _emailError = 'يرجى إدخال البريد الإلكتروني';
      hasError = true;
    } else if (!_isValidEmail(email)) {
      _emailError = 'البريد الإلكتروني غير صالح';
      hasError = true;
    }

    if (password.isEmpty) {
      _passwordError = 'يرجى إدخال كلمة المرور';
      hasError = true;
    } else {
      String passwordValidation = _validatePassword(password);
      if (passwordValidation.isNotEmpty) {
        _passwordError = passwordValidation;
        hasError = true;
      }
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'يرجى تأكيد كلمة المرور';
      hasError = true;
    } else if (password != confirmPassword) {
      _confirmPasswordError = 'كلمات المرور غير متطابقة';
      hasError = true;
    }

    if (hasError) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      List<String> methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _emailError = 'هذا البريد الإلكتروني مستخدم بالفعل';
        });
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final defaultTimestamp = DateTime.utc(2025, 4, 18, 21, 0, 0);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'username': username,
        'email': email,
        'coins': 0,
        'challenge_answered': false,
        'challenge_timestamp': Timestamp.fromDate(defaultTimestamp),
      });

      _showSuccessDialog(context);

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _generalError = 'حدث خطأ: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _generalError = 'حدث خطأ غير متوقع';
      });
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: const Color.fromARGB(255, 157, 192, 139),
        title: Text(
          'نجاح',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          'تم إنشاء الحساب بنجاح!',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
              );
            },
            child: Text(
              'حسناً',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 60),
                  Image.asset('assets/logo.png', height: 80),
                  SizedBox(height: 20),
                  _buildToggleButtons(context, isSignup: true),
                  SizedBox(height: 30),
                  if (_generalError != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        _generalError!,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'أهلاً بك! \nسجل البيانات التالية لإنشاء حساب',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextField(
                    "الاسم",
                    "ادخل اسمك",
                    Icons.person,
                    _usernameController,
                    errorText: _usernameError,
                  ),
                  _buildTextField(
                    "الإيميل",
                    "example@example.com",
                    Icons.email,
                    _emailController,
                    errorText: _emailError,
                  ),
                  _buildPasswordField(
                    "كلمة المرور",
                    Icons.lock,
                    _passwordController,
                    isConfirm: false,
                    errorText: _passwordError,
                  ),
                  _buildPasswordField(
                    "تأكيد كلمة المرور",
                    Icons.lock,
                    _confirmPasswordController,
                    isConfirm: true,
                    errorText: _confirmPasswordError,
                  ),
                  SizedBox(height: 20),
                  _buildMainButton("إنشاء حساب", _signup),
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "إذا كان لديك حساب مسبق ",
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
                  SizedBox(height: 40),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF609966)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      String hint,
      IconData icon,
      TextEditingController controller, {
        String? errorText,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              labelStyle: TextStyle(color: Colors.black87),
              prefixIcon: Icon(icon),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: EdgeInsets.only(right: 12, top: 4),
              child: Text(
                errorText,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
      String label,
      IconData icon,
      TextEditingController controller, {
        required bool isConfirm,
        String? errorText,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textAlign: TextAlign.right,
            obscureText: isConfirm ? !_isConfirmPasswordVisible : !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  isConfirm
                      ? (_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off)
                      : (_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                ),
                onPressed: () {
                  setState(() {
                    if (isConfirm) {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    } else {
                      _isPasswordVisible = !_isPasswordVisible;
                    }
                  });
                },
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: EdgeInsets.only(right: 12, top: 4),
              child: Text(
                errorText,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF609966),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }

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
              onTap: () {},
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isSignup ? Color(0xFF609966) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'إنشاء حساب',
                    style: TextStyle(
                      color: isSignup ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: !isSignup ? Color(0xFF609966) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      color: !isSignup ? Colors.white : Colors.grey,
                    ),
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
