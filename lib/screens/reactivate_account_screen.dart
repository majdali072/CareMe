import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'otp_verification_screen.dart';

/// Lets a user with a deactivated account prove ownership and re-enable it.
/// Email is prefilled and read-only. For password accounts the user must
/// re-enter their password; Google accounts skip the password step.
/// On success, [onReactivated] fires with the user's name/email/admin flag —
/// the caller routes the user straight to the home screen.
class ReactivateAccountScreen extends StatefulWidget {
  final String email;
  final bool isGoogleAccount;
  final void Function(String name, String email, bool isAdmin) onReactivated;

  const ReactivateAccountScreen({
    super.key,
    required this.email,
    required this.isGoogleAccount,
    required this.onReactivated,
  });

  @override
  State<ReactivateAccountScreen> createState() =>
      _ReactivateAccountScreenState();
}

class _ReactivateAccountScreenState extends State<ReactivateAccountScreen> {
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleSendCode() {
    setState(() => _errorMessage = null);

    if (!widget.isGoogleAccount && _passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage =
          AppLocalizations.of(context).t('reactivate_password_required'));
      return;
    }

    // OTPVerificationScreen sends the OTP itself in initState; calling
    // ApiService.sendOtp here too would deliver a duplicate email.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerificationScreen(
          verificationType: 'email',
          contactInfo: widget.email,
          // The reactivate endpoint verifies password + OTP atomically, so
          // don't consume the OTP via /verify-otp/.
          skipBackendVerify: true,
          onVerify: (otp) async {
            await _completeReactivation(otp);
          },
        ),
      ),
    );
  }

  Future<void> _completeReactivation(String otp) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1976D2))),
    );
    try {
      final result = await ApiService.reactivateAccount(
        email: widget.email,
        otpCode: otp,
        password: widget.isGoogleAccount ? null : _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      Navigator.of(context).pop(); // dismiss OTP screen
      Navigator.of(context).pop(); // dismiss reactivate screen
      final user = result['user'] as Map<String, dynamic>;
      widget.onReactivated(
        (user['name'] as String?) ?? widget.email.split('@').first,
        (user['email'] as String?) ?? widget.email,
        user['is_admin'] == true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('reactivate_server_error')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        children: [
          // Header — same gradient as login / OTP screens.
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Icon(Icons.arrow_back,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).t('reactivate_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow(context).withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/CareMe_Logo.png',
                          width: 88,
                          height: 88,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        AppLocalizations.of(context).t('reactivate_verify_title'),
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        widget.isGoogleAccount
                            ? AppLocalizations.of(context).t('reactivate_desc_google')
                            : AppLocalizations.of(context).t('reactivate_desc_password'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email (read-only)
                    Text(AppLocalizations.of(context).t('auth_email'),
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    TextField(
                      controller:
                          TextEditingController(text: widget.email),
                      readOnly: true,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline,
                            color: AppColors.textMuted(context), size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceAlt(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: AppColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: AppColors.border(context)),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    if (!widget.isGoogleAccount) ...[
                      const SizedBox(height: 14),
                      Text(AppLocalizations.of(context).t('auth_password'),
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        style:
                            TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: TextStyle(
                              color: AppColors.textMuted(context)),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: AppColors.textMuted(context), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textMuted(context),
                                size: 20),
                            onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceAlt(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppColors.border(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppColors.border(context)),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border:
                              Border.all(color: const Color(0xFFFECACA)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _handleSendCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(AppLocalizations.of(context).t('reactivate_send_code_button'),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        AppLocalizations.of(context).t('reactivate_code_note'),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
