import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String name, String email, bool isAdmin) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegistering = false;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  bool _passwordMeetsAll(String password) =>
      password.length >= 8 &&
      password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[a-z]')) &&
      password.contains(RegExp(r'[0-9]')) &&
      password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  void _setError(String? msg) {
    if (!mounted) return;
    setState(() => _errorMessage = msg);
  }

  void _handleSubmit() async {
    _setError(null);

    if (_isRegistering && !_acceptedTerms) {
      setState(() => _showTermsError = true);
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : email.split('@').first;

    if (email.isEmpty || password.isEmpty) {
      _setError('Please fill in all fields.');
      return;
    }
    if (!_isValidEmail(email)) {
      _setError('Please enter a valid email address.');
      return;
    }

    if (_isRegistering) {
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
        _setError("The two passwords don't match.");
        return;
      }
      if (!_passwordMeetsAll(password)) {
        _setError('Your password does not meet all requirements yet.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      late final Map<String, dynamic> result;
      if (_isRegistering) {
        result = await ApiService.register(
          name: name,
          email: email,
          password: password,
        );
      } else {
        result = await ApiService.login(
          email: email,
          password: password,
        );
      }
      if (mounted) {
        final userName = result['user']['name'] as String;
        final userEmail = result['user']['email'] as String;
        final isAdmin = result['user']['is_admin'] == true;
        if (isAdmin) {
          widget.onLogin(userName, userEmail, isAdmin);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OTPVerificationScreen(
                verificationType: 'email',
                contactInfo: userEmail,
                onVerify: (_) {
                  Navigator.pop(context);
                  widget.onLogin(userName, userEmail, isAdmin);
                },
              ),
            ),
          );
        }
      }
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError("Couldn't reach the server. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    _setError(null);
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: [
        'email',
        'profile',
        'https://www.googleapis.com/auth/calendar',
      ]);
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled the sign-in
        return;
      }
      final name = account.displayName ?? account.email.split('@').first;
      final email = account.email;

      // Authenticate with backend so the user gets a JWT token
      // (fixes AI chatbot and all other API calls)
      try {
        final result = await ApiService.googleAuth(name: name, email: email);
        if (mounted) {
          final userName = result['user']['name'] as String;
          final userEmail = result['user']['email'] as String;
          final isAdmin = result['user']['is_admin'] == true;
          widget.onLogin(userName, userEmail, isAdmin);
        }
      } on ApiException catch (e) {
        _setError(e.message);
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _setError("Google sign-in failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTermsModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(bottom: BorderSide(color: AppColors.border(context))),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Terms & Privacy',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary(context))),
                  IconButton(
                      icon: Icon(Icons.close, color: AppColors.textPrimary(context)),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _termsSection('Terms of Service', _termsContent),
                    const SizedBox(height: 16),
                    _termsSection('Privacy Policy', _privacyContent),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _acceptedTerms = true;
                            _showTermsError = false;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('I Accept Terms & Privacy Policy'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termsSection(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(content,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
          ),
        ],
      ),
    );
  }

  static const String _termsContent = '''1. Acceptance of Terms
By accessing and using CareMe, you accept and agree to be bound by these Terms of Service.

2. Description of Service
CareMe is a healthcare management application that helps users track medications, lab test results, and medical appointments. It is not a substitute for professional medical advice.

3. User Accounts
You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account.

4. Medical Disclaimer
THE APP IS NOT A MEDICAL DEVICE AND DOES NOT PROVIDE MEDICAL ADVICE. Always seek the advice of your physician for any medical condition.

5. User Responsibilities
You agree to use the App only for lawful purposes and are solely responsible for the accuracy of your health information.

6. Limitation of Liability
IN NO EVENT SHALL CAREME BE LIABLE FOR ANY INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF YOUR USE OF THE APP.''';

  static const String _privacyContent = '''1. Information We Collect
Personal Information: Name, email, phone, date of birth, and address. Health Information: Medication records, lab results, appointment details.

2. How We Use Your Information
To provide app functionality, send reminders, improve user experience, and ensure account security.

3. Data Security
We implement industry-standard security measures. Your data is encrypted in transit and at rest.

4. Data Sharing
We do not sell, trade, or rent your personal or health information to third parties.

5. Your Privacy Rights
You have the right to access, correct, delete, and export your personal data at any time.

6. HIPAA Compliance
This App is designed for personal use and is not a HIPAA-covered entity.

Contact: support@careme.app''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF4F46E5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/CareMe-Logo.png',
                      width: 180,
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(context).withOpacity(0.97),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRegistering
                              ? 'Sign up to get started'
                              : 'Sign in to continue',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: 20),
                        if (_isRegistering) ...[
                          _buildTextField(_nameCtrl, 'Full Name',
                              Icons.person_outline, 'John Doe'),
                          const SizedBox(height: 14),
                        ],
                        _buildTextField(_emailCtrl, 'Email', Icons.mail_outline,
                            'you@example.com',
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildPasswordField(
                            _passwordCtrl,
                            'Password',
                            _obscurePassword,
                            () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            onChanged: _isRegistering ? (_) => setState(() {}) : null),
                        if (_isRegistering) ...[
                          _buildPasswordStrengthBar(_passwordCtrl.text),
                          const SizedBox(height: 8),
                          _buildPasswordChecklist(_passwordCtrl.text),
                          const SizedBox(height: 14),
                          _buildPasswordField(
                              _confirmPasswordCtrl,
                              'Confirm Password',
                              _obscureConfirm,
                              () => setState(
                                  () => _obscureConfirm = !_obscureConfirm)),
                          const SizedBox(height: 14),
                          _buildTermsRow(),
                        ],
                        if (_showTermsError)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                                'Please accept the Terms & Privacy Policy to continue.',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          _buildErrorBanner(_errorMessage!),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Text(
                                    _isRegistering
                                        ? 'Create Account'
                                        : 'Sign In',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                        if (!_isRegistering) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              icon: Image.asset(
                                'assets/Google_Logo.webp',
                                width: 20,
                                height: 20,
                              ),
                              label: Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: AppColors.border(context)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                backgroundColor: AppColors.surface(context),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  _isRegistering
                                      ? 'Already have an account? '
                                      : "Don't have an account? ",
                                  style: TextStyle(
                                      color: AppColors.textSecondary(context), fontSize: 14)),
                              GestureDetector(
                                onTap: () => setState(
                                    () => _isRegistering = !_isRegistering),
                                child: Text(
                                  _isRegistering ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isRegistering) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OTPVerificationScreen(
                                      verificationType: 'email',
                                      contactInfo: _emailCtrl.text.trim(),
                                      onVerify: (otp) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Verified successfully!')),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Forgot password?',
                                  style: TextStyle(
                                      color: Color(0xFF2563EB), fontSize: 13)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text('Secure • Private • HIPAA Compliant',
                      style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            prefixIcon: Icon(icon, color: AppColors.textMuted(context), size: 20),
            filled: true,
            fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(TextEditingController ctrl, String label,
      bool obscure, VoidCallback toggle, {ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          onChanged: onChanged,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            prefixIcon: Icon(Icons.lock_outline,
                color: AppColors.textMuted(context), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted(context),
                  size: 20),
              onPressed: toggle,
            ),
            filled: true,
            fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Inline error banner (replaces snackbars) ──────────────────────────────
  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () => _setError(null),
            child: const Icon(Icons.close,
                color: Color(0xFF991B1B), size: 16),
          ),
        ],
      ),
    );
  }

  // ── Live password requirement checklist ───────────────────────────────────
  Widget _buildPasswordChecklist(String password) {
    final rules = <_PwRule>[
      _PwRule('At least 8 characters', password.length >= 8),
      _PwRule('One uppercase letter (A-Z)',
          password.contains(RegExp(r'[A-Z]'))),
      _PwRule('One lowercase letter (a-z)',
          password.contains(RegExp(r'[a-z]'))),
      _PwRule('One number (0-9)', password.contains(RegExp(r'[0-9]'))),
      _PwRule('One special character (!@#\$ etc.)',
          password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        border: Border.all(color: AppColors.border(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your password needs:',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 6),
          for (final r in rules) ...[
            Row(
              children: [
                Icon(
                  r.met
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: r.met
                      ? const Color(0xFF16A34A)
                      : AppColors.textMuted(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.met
                          ? AppColors.textPrimary(context)
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthBar(String password) {
    if (password.isEmpty) return const SizedBox.shrink();

    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;

    final labels = ['Very Weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      const Color(0xFFDC2626),
      const Color(0xFFF97316),
      const Color(0xFFEAB308),
      const Color(0xFF22C55E),
      const Color(0xFF16A34A),
    ];

    final index = (score - 1).clamp(0, 4);
    final label = labels[index];
    final color = colors[index];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < score ? color : AppColors.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _acceptedTerms,
            onChanged: (val) => setState(() {
              _acceptedTerms = val == true;
              _showTermsError = false;
            }),
            activeColor: const Color(0xFF2563EB),
          ),
          Expanded(
            child: Wrap(
              children: [
                Text('I accept the ', style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context))),
                GestureDetector(
                  onTap: _showTermsModal,
                  child: const Text('Terms & Privacy Policy',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PwRule {
  final String label;
  final bool met;
  const _PwRule(this.label, this.met);
}

