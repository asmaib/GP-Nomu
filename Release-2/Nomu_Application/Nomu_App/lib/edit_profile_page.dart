import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  final String currentName;
  final String currentEmail; 

  const EditProfilePage({
    Key? key,
    required this.currentName,
    required this.currentEmail,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final String newName = _nameController.text.trim();

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorText = 'لا يوجد مستخدم مسجل حالياً.';
      });
      return;
    }

    // Only proceed if the name has changed
    bool changesHappened = (newName != widget.currentName);
    if (!changesHappened) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color.fromARGB(255, 157, 192, 139),
        title: const Text(
          'تأكيد',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تعديل معلوماتك الشخصية؟',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'تأكيد',
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Update the display name in Firebase Authentication
      await user.updateDisplayName(newName);

      // Update the name in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'username': newName,
      });

      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color.fromARGB(255, 157, 192, 139),
          title: const Text(
            'نجاح',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'تم تحديث البيانات بنجاح',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'حسناً',
                style: TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
          ],
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'حدث خطأ في تحديث البيانات: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'حدث خطأ غير متوقع: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
  preferredSize: Size.fromHeight(kToolbarHeight),
  child: AppBar(
    backgroundColor: Color(0xFF609966),
    elevation: 0,
    automaticallyImplyLeading: false,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(width: 48),

        Expanded(
          child: Text(
            'تعديل المعلومات الشخصية',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),

          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  ),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                 TextFormField(
                        controller: _nameController,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'الاسم',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال الاسم';
                          }
                          String trimmed = value.trim();
                          if (trimmed.length < 2 || trimmed.length > 50) {
                            return 'يجب أن يكون الاسم بين 2 و50 حرفاً';
                          }
                          // Regular expression: only allows English letters, Arabic letters, and spaces.
                          if (!RegExp(r'^[a-zA-Z\u0621-\u064A\s]+$').hasMatch(trimmed)) {
                            return 'يرجى إدخال الأحرف فقط، بدون أرقام أو رموز خاصة';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24),
                      _isLoading
                          ? CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF609966),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'حفظ التعديلات',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                      if (_errorText != null) ...[
                        SizedBox(height: 16),
                        Text(
                          _errorText!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
