import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سياسة الخصوصية'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سياسة الخصوصية لتطبيق دليل حافلات ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'نحن في تطبيق دليل حافلات إنجاز نقدر خصوصيتك ونلتزم بحماية معلوماتك الشخصية. توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية المعلومات التي تقدمها لنا.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            _buildSection(
              'المعلومات التي نجمعها',
              'نقوم بجمع المعلومات التالية:\n\n'
                  '• المعلومات التي تقدمها طوعًا مثل اسمك وعنوان بريدك الإلكتروني\n'
                  '• معلومات الموقع الجغرافي لتحديد أقرب محطات الحافلات\n'
                  '• بيانات الاستخدام لتحسين التطبيق\n'
                  '• معلومات الجهاز لأغراض التحليل والأمان',
            ),
            _buildSection(
              'كيف نستخدم معلوماتك',
              'نستخدم المعلومات المجمعة للأغراض التالية:\n\n'
                  '• تقديم خدمات التطبيق وتحسينها\n'
                  '• إرسال إشعارات مهمة حول الرحلات\n'
                  '• تحليل استخدام التطبيق لتطويره\n'
                  '• ضمان أمان المستخدمين',
            ),
            _buildSection(
              'مشاركة المعلومات',
              'نحن لا نبيع أو نؤجر أو نشارك معلوماتك الشخصية مع أطراف ثالثة إلا في الحالات التالية:\n\n'
                  '• عند الحصول على موافقتك الصريحة\n'
                  '• للامتثال للقوانين واللوائح\n'
                  '• لحماية حقوقنا أو سلامة الآخرين',
            ),
            _buildSection(
              'أمان البيانات',
              'نتخذ تدابير أمنية مناسبة لحماية معلوماتك من الوصول غير المصرح به أو التغيير أو الكشف أو التدمير.',
            ),
            _buildSection(
              'حقوقك',
              'لديك الحق في:\n\n'
                  '• الوصول إلى معلوماتك الشخصية\n'
                  '• تصحيح المعلومات غير الدقيقة\n'
                  '• حذف معلوماتك\n'
                  '• سحب الموافقة على معالجة البيانات',
            ),
            _buildSection(
              'اتصل بنا',
              'إذا كان لديك أي أسئلة حول سياسة الخصوصية هذه، يمكنك الاتصال بنا عبر:\n\n'
                  'البريد الإلكتروني: enjaz121@gmail.com\n'
                  ': ',
            ),
            const SizedBox(height: 20),
            const Text(
              'المعلومات استرشادية وقد تختلف حسب ظروف التشغيل',
              style: TextStyle(fontSize: 16, height: 1.5),
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
