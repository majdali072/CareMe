import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String verificationType; // "email" or "phone"
  final String contactInfo;
  final void Function(String otp) onVerify;

  /// When false (default), the screen calls `ApiService.verifyOtp` itself —
  /// the OTP is consumed server-side before `onVerify` fires. Set this to
  /// true when the caller will hand the code to a different endpoint that
  /// performs the verification atomically (e.g. reactivate-account).
  final bool skipBackendVerify;

  /// Optional override for the initial OTP send. Defaults to calling
  /// `ApiService.sendOtp(contactInfo)`. Provide this when the caller has
  /// already issued the code through a different path.
  final Future<void> Function()? onSendOtp;

  /// Why the OTP is being sent (e.g. 'change_password'). Forwarded to the
  /// backend so the email wording matches the action. Defaults to email
  /// verification when null.
  final String? purpose;

  const OTPVerificationScreen({
    super.key,
    this.verificationType = 'email',
    this.contactInfo = '',
    required this.onVerify,
    this.skipBackendVerify = false,
    this.onSendOtp,
    this.purpose,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _keyboardFocusNodes =
      List.generate(6, (_) => FocusNode());

  String? _alertType; // "success", "error", or null
  String _errorMessage = '';
  int _resendTimer = 60;
  bool _canResend = false;
  bool _isSending = false;
  bool _isVerifying = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _focusNodes[0].requestFocus();
    _startTimer();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    if (_isSending) return;
    if (mounted) setState(() => _isSending = true);
    try {
      if (widget.onSendOtp != null) {
        await widget.onSendOtp!();
      } else {
        await ApiService.sendOtp(widget.contactInfo, purpose: widget.purpose);
      }
      if (mounted) setState(() => _isSending = false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _alertType = 'error';
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).t('login_cant_reach_server');
          _alertType = 'error';
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyboardFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _resendTimer = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer <= 1) {
          _canResend = true;
          timer.cancel();
          _resendTimer = 0;
        } else {
          _resendTimer--;
        }
      });
    });
  }

  void _handleChange(int index, String value) {
    if (value.length > 1) {
      // Handle paste into a single field
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        _controllers[index].clear();
        return;
      }
      // Fill from current index
      for (int i = 0; i < digits.length && (index + i) < 6; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
      setState(() => _alertType = null);
      return;
    }

    if (value.isNotEmpty && !RegExp(r'^\d$').hasMatch(value)) {
      _controllers[index].clear();
      return;
    }

    setState(() => _alertType = null);

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  String get _otpCode =>
      _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    final code = _otpCode.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).t('otp_enter_all_digits');
        _alertType = 'error';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _alertType = null;
    });

    try {
      if (!widget.skipBackendVerify) {
        await ApiService.verifyOtp(widget.contactInfo, code);
      }
      if (!mounted) return;
      setState(() => _alertType = 'success');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      widget.onVerify(code);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _alertType = 'error';
          _isVerifying = false;
        });
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).t('login_cant_reach_server');
          _alertType = 'error';
          _isVerifying = false;
        });
      }
    }
  }

  void _handleResend() {
    if (!_canResend) return;
    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _alertType = null);
    _focusNodes[0].requestFocus();
    _startTimer();
    _sendOtp();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final contactLabel = widget.contactInfo.isNotEmpty
        ? widget.contactInfo
        : (widget.verificationType == 'email' ? 'your email' : 'your phone');

    return Scaffold(
      body: Column(
        children: [
          // Header
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).t('otp_header_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: Container(
              color: AppColors.background(context),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 27),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          // Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                              ),
                            ),
                            child: Icon(
                              widget.verificationType == 'email'
                                  ? Icons.mail_outline
                                  : Icons.phone,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            AppLocalizations.of(context).t('otp_card_title'),
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Description
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(text: AppLocalizations.of(context).t('otp_sent_prefix')),
                                TextSpan(
                                  text: contactLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context).t('otp_check_spam'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted(context),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // OTP Input Fields
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Flexible(
                                child: Container(
                                height: 56,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                child: KeyboardListener(
                                  focusNode: _keyboardFocusNodes[index],
                                  onKeyEvent: (event) => _handleKeyEvent(index, event),
                                  child: TextField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary(context),
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: AppColors.surfaceAlt(context),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppColors.border(context),
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppColors.border(context),
                                          width: 2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF1976D2),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) => _handleChange(index, value),
                                  ),
                                ),
                              ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),

                          const SizedBox(height: 24),

                          // Alerts
                          if (_alertType == 'success')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context).t('otp_success_snack'),
                                    style: const TextStyle(
                                      color: Color(0xFF166534),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_alertType == 'error')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                border: Border.all(color: const Color(0xFFFECACA)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: const TextStyle(color: Color(0xFF991B1B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Verify Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isVerifying ? null : _handleVerify,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isVerifying
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5),
                                      )
                                    : Text(
                                        AppLocalizations.of(context).t('otp_verify_button_code'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Resend Code
                          Text(
                            AppLocalizations.of(context).t('otp_didnt_receive'),
                            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (_isSending)
                            Text(
                              AppLocalizations.of(context).t('otp_sending_code'),
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 14,
                              ),
                            )
                          else if (_canResend)
                            GestureDetector(
                              onTap: _handleResend,
                              child: Text(
                                AppLocalizations.of(context).t('otp_resend_button'),
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: AppLocalizations.of(context).t('otp_resend_available_in')),
                                  TextSpan(
                                    text: _formatTime(_resendTimer),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Additional Info
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).t('otp_expires_note'),
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                      textAlign: TextAlign.center,
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
