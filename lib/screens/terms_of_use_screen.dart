import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شروط الاستخدام'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'شروط استخدام تطبيق دليل حافلات إنجاز',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'مرحباً بك في تطبيق دليل حافلات القاهرة. باستخدام هذا التطبيق، فإنك توافق على الالتزام بشروط الاستخدام التالية. يرجى قراءتها بعناية قبل استخدام التطبيق.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            _buildSection(
              'قبول الشروط',
              'باستخدام هذا التطبيق، فإنك توافق على الالتزام بهذه الشروط وجميع القوانين واللوائح المعمول بها. إذا كنت لا توافق على أي من هذه الشروط، يُمنع عليك استخدام هذا التطبيق.',
            ),
            _buildSection(
              'وصف الخدمة',
              'تطبيق دليل حافلات القاهرة هو خدمة تقدم معلومات حول خطوط الحافلات والمحطات في القاهرة. نحن نحرص على دقة المعلومات ولكن لا نضمن دقتها المطلقة.',
            ),
            _buildSection(
              'استخدام التطبيق',
              'يُسمح لك باستخدام التطبيق للأغراض الشخصية غير التجارية فقط. يُمنع عليك:\n\n'
                  '• نسخ أو توزيع محتوى التطبيق\n'
                  '• استخدام التطبيق لأغراض غير قانونية\n'
                  '• محاولة اختراق أو إلحاق الضرر بالتطبيق\n'
                  '• استخدام التطبيق بطريقة تؤثر على أدائه',
            ),
            _buildSection(
              'المحتوى والملكية الفكرية',
              'جميع المحتويات في التطبيق محمية بحقوق الطبع والنشر والعلامات التجارية. لا يحق لك استخدام هذه المحتويات دون إذن كتابي مسبق.',
            ),
            _buildSection(
              'الخصوصية',
              'نحن نحترم خصوصيتك ونلتزم بحماية معلوماتك الشخصية. يرجى مراجعة سياسة الخصوصية لمعرفة المزيد حول كيفية جمع واستخدام بياناتك.',
            ),
            _buildSection(
              'الإخلاء من المسؤولية',
              'التطبيق يُقدم "كما هو" دون أي ضمانات. نحن لا نتحمل مسؤولية أي أضرار مباشرة أو غير مباشرة ناتجة عن استخدام التطبيق.',
            ),
            _buildSection(
              'التعديلات',
              'نحتفظ بالحق في تعديل هذه الشروط في أي وقت. سيتم إشعار المستخدمين بأي تغييرات جوهرية.',
            ),
            _buildSection(
              'القانون المعمول به',
              'تخضع هذه الشروط لقوانين جمهورية مصر العربية. أي نزاع ينشأ عن هذه الشروط سيخضع لاختصاص محاكم القاهرة.',
            ),
            _buildSection(
              'اتصل بنا',
              'إذا كان لديك أي أسئلة حول شروط الاستخدام هذه، يمكنك الاتصال بنا عبر:\n\n'
                  'البريد الإلكتروني: enjaz121@gmail.com\n'
                  ':    ',
            ),
            const SizedBox(height: 20),
            const Text(
              'آخر تحديث: ديسمبر 2025',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );
  }
}
