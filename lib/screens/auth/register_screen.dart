import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../screens/home_screen.dart';
import 'terms_screen.dart'; // شاشة الشروط والأحكام (هنعملها بعدين)

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w.\%+-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());
  }

  String? _passwordStrength(String password) {
    if (password.isEmpty) return null;
    if (password.length < 6) return 'ضعيف';
    if (password.length < 8) return 'متوسط';
    if (RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      return 'قوي';
    }
    return 'جيد';
  }

  Color _strengthColor(String? strength) {
    switch (strength) {
      case 'ضعيف':
        return Colors.red;
      case 'متوسط':
        return Colors.orange;
      case 'جيد':
        return Colors.blue;
      case 'قوي':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _register() async {
    if (!_acceptTerms) {
      _showSnackBar('يجب الموافقة على الشروط والأحكام', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await auth.register(email, password, name);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, textDirection: TextDirection.rtl)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);

    // إذا سجل بنجاح، ننتقل تلقائيًا
    if (auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            'assets/images/play_store_512.png',
                            height: 80,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Text(
                        'مرحبًا بك في تطبيق المواصلات!',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'سجل حسابك الآن وابدأ رحلتك في شوارع القاهرة بسهولة',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 32),

                      // Name
                      _buildTextField(
                        controller: _nameController,
                        label: 'اسمك الكامل',
                        hint: 'أحمد محمد علي',
                        icon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        hint: 'mail@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.isEmpty) return 'مطلوب';
                          if (!_isValidEmail(v)) return 'بريد غير صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _buildTextField(
                        controller: _passwordController,
                        label: 'كلمة المرور',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        onChanged: (v) => setState(() {}),
                        validator: (v) {
                          if (v!.isEmpty) return 'مطلوب';
                          if (v.length < 6) return '6 أحرف على الأقل';
                          return null;
                        },
                      ),

                      // Password Strength
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('قوة كلمة المرور: '),
                            Text(
                              _passwordStrength(_passwordController.text) ?? 'ضعيف',
                              style: TextStyle(
                                color: _strengthColor(_passwordStrength(_passwordController.text)),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Confirm Password
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'تأكيد كلمة المرور',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return 'مطلوب';
                          if (v != _passwordController.text) return 'غير متطابقة';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Terms
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black87, fontSize: 14),
                                children: [
                                  const TextSpan(text: 'أوافق على '),
                                  TextSpan(
                                    text: 'الشروط والأحكام',
                                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const TermsScreen()),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Register Button
                      ElevatedButton(
                        onPressed: auth.isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                            : const Text('إنشاء الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),

                      // Social Register
                      const Text('أو سجل بـ', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton(FontAwesomeIcons.google, Colors.red, () => auth.loginWithGoogle()),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Global Loading
          if (auth.isLoading)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),

          // Error Banner
          if (auth.errorMessage != null)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: Colors.red.shade600,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(auth.errorMessage!, style: const TextStyle(color: Colors.white))),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: auth.clearError),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffixIcon,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          textDirection: TextDirection.rtl,
          validator: validator,
        ),
      ],
    );
  }

  Widget _socialButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FaIcon(icon, color: color, size: 32),
      ),
    );
  }
}