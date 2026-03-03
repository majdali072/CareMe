import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String name, String email) onLogin;
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

  void _handleSubmit() {
    if (_isRegistering && !_acceptedTerms) {
      setState(() => _showTermsError = true);
      return;
    }
    if (_isRegistering && _passwordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
      return;
    }
    final email = _emailCtrl.text;
    final name = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text
        : email.split('@').first;
    widget.onLogin(name, email);
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
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Terms & Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
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
                          setState(() { _acceptedTerms = true; _showTermsError = false; });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111418),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
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
                  // Logo / Icon
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 8),
                  const Text('CareMe', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 24),

                  // Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.97),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRegistering ? 'Sign up to get started' : 'Sign in to continue',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                        ),
                        const SizedBox(height: 20),

                        if (_isRegistering) ...[
                          _buildTextField(_nameCtrl, 'Full Name', Icons.person_outline, 'John Doe'),
                          const SizedBox(height: 14),
                        ],
                        _buildTextField(_emailCtrl, 'Email', Icons.mail_outline, 'you@example.com', keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildPasswordField(_passwordCtrl, 'Password', _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)),
                        if (_isRegistering) ...[
                          const SizedBox(height: 14),
                          _buildPasswordField(_confirmPasswordCtrl, 'Confirm Password', _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
                          const SizedBox(height: 14),
                          _buildTermsRow(),
                        ],
                        if (_showTermsError)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('Please accept the Terms & Privacy Policy to continue.', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: Text(_isRegistering ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isRegistering ? 'Already have an account? ' : "Don't have an account? ", style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                              GestureDetector(
                                onTap: () => setState(() => _isRegistering = !_isRegistering),
                                child: Text(
                                  _isRegistering ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isRegistering) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot password?', style: TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text('Secure • Private • HIPAA Compliant', style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 13)),
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
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF), size: 20),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF9CA3AF), size: 20),
              onPressed: toggle,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _acceptedTerms,
            onChanged: (val) => setState(() { _acceptedTerms = val == true; _showTermsError = false; }),
            activeColor: const Color(0xFF2563EB),
          ),
          Expanded(
            child: Wrap(
              children: [
                const Text('I accept the ', style: TextStyle(fontSize: 13)),
                GestureDetector(
                  onTap: _showTermsModal,
                  child: const Text('Terms & Privacy Policy', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
