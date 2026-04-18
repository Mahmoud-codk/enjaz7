import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  bool isLogin = true; // تبديل بين تسجيل الدخول والتسجيل

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'تسجيل الدخول' : 'التسجيل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (!isLogin)
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
              const SizedBox(height: 20),
              if (auth.errorMessage != null)
                Text(auth.errorMessage!,
                    style: const TextStyle(color: Colors.red)),
              if (auth.successMessage != null)
                Text(auth.successMessage!,
                    style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 20),
              auth.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (isLogin) {
                          await auth.login(
                              emailController.text, passwordController.text);
                        } else {
                          await auth.register(emailController.text,
                              passwordController.text, nameController.text);
                        }
                      },
                      child: Text(isLogin ? 'تسجيل الدخول' : 'التسجيل'),
                    ),
              TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(isLogin
                      ? 'ليس لديك حساب؟ سجل الآن'
                      : 'لديك حساب؟ سجل الدخول')),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => auth.loginWithGoogle(),
                icon: const Icon(Icons.login),
                label: const Text('تسجيل الدخول بـ Google'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => auth.resetPassword(emailController.text),
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}