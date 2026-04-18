import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشروط والأحكام'),
        centerTitle: true,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            'هنا يمكنك وضع نص الشروط والأحكام الكامل.\n\n'
            'مثال: يجب على المستخدمين الالتزام بالقوانين واللوائح.\n'
            'التطبيق مسؤول عن البيانات المدخلة.\n\n'
            'إلخ...',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
