import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _handleChangePassword() async {
    final t = AppLocalizations.of(context);
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('login_fill_all_fields'))),
      );
      return;
    }

    final issues = <String>[];
    if (password.length < 8) issues.add(t.t('cp_issue_length'));
    if (!password.contains(RegExp(r'[A-Z]'))) issues.add(t.t('cp_issue_upper'));
    if (!password.contains(RegExp(r'[a-z]'))) issues.add(t.t('cp_issue_lower'));
    if (!password.contains(RegExp(r'[0-9]'))) issues.add(t.t('cp_issue_number'));
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) issues.add(t.t('cp_issue_special'));
    if (issues.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('cp_password_contains_prefix', {'issues': issues.join(", ")}))),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('cp_pw_mismatch_bang'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.changePassword(password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('cp_changed_success'))),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('cp_connection_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                      'assets/CareMe_Logo.png',
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
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).t('cp_create_new_title'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).t('cp_requirements_note'),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // New Password
                        _buildPasswordField(
                          _passwordCtrl,
                          AppLocalizations.of(context).t('cp_new'),
                          _obscurePassword,
                          () => setState(() => _obscurePassword = !_obscurePassword),
                          onChanged: (_) => setState(() {}),
                        ),
                        _buildPasswordStrengthBar(_passwordCtrl.text),
                        const SizedBox(height: 14),

                        // Confirm Password
                        _buildPasswordField(
                          _confirmCtrl,
                          AppLocalizations.of(context).t('auth_confirm_password'),
                          _obscureConfirm,
                          () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        const SizedBox(height: 20),

                        // Change Password Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleChangePassword,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    AppLocalizations.of(context).t('cp_change_password_btn'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Back button
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              AppLocalizations.of(context).t('common_cancel'),
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).t('login_secure_badge'),
                    style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback toggle, {
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          onChanged: onChanged,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted(context), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textMuted(context),
                size: 20,
              ),
              onPressed: toggle,
            ),
            filled: true,
            fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
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

    final t = AppLocalizations.of(context);
    final labels = [
      t.t('login_strength_very_weak'),
      t.t('login_strength_weak'),
      t.t('login_strength_fair'),
      t.t('login_strength_good'),
      t.t('login_strength_strong'),
    ];
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
}
