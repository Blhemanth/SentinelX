// SentinelX - Login Screen
// Adaptive auth UI: dark glassmorphic panel with JWT login form.
// Role-aware: on success, routes to AppShell with the user's role baked in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentinel_x/core/theme/sentinel_theme.dart';
import 'package:sentinel_x/core/providers/auth_provider.dart';
import 'package:sentinel_x/shell/app_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'admin@sentinelx.local');
  final _passwordCtrl = TextEditingController(text: 'ChangeMe!2024');

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.login(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } else {
      setState(() => _errorMessage = result.error ?? 'Login failed. Check your credentials.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 600;

    return Scaffold(
      backgroundColor: SentinelColors.bgDarkest,
      body: Container(
        decoration: const BoxDecoration(gradient: SentinelGradients.surfaceGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? size.width * 0.28 : 24,
              vertical: 40,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Brand ──────────────────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: SentinelGradients.primaryGradient,
                    borderRadius: SentinelRadius.smAll,
                    boxShadow: SentinelShadows.glow,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'SentinelX',
                  style: SentinelTypography.headlineLarge.copyWith(
                    foreground: Paint()
                      ..shader = SentinelGradients.primaryGradient.createShader(
                        const Rect.fromLTWH(0, 0, 200, 40),
                      ),
                  ),
                ),
                Text(
                  'URBAN ANOMALY DETECTION SYSTEM',
                  style: SentinelTypography.labelSmall.copyWith(
                    color: SentinelColors.textTertiary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Login Card ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: SentinelColors.bgCard.withValues(alpha: 0.65),
                    borderRadius: SentinelRadius.lgAll,
                    border: Border.all(color: SentinelColors.glassBorder),
                    boxShadow: SentinelShadows.soft,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'SECURE ACCESS',
                          style: SentinelTypography.headlineMedium.copyWith(
                            color: SentinelColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Authorized security personnel only',
                          style: SentinelTypography.bodySmall.copyWith(
                            color: SentinelColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Role Selector Pills (Quick Demo Switcher)
                        Row(
                          children: [
                            _buildRolePill('Admin', 'admin@sentinelx.local'),
                            const SizedBox(width: 6),
                            _buildRolePill('Police', 'police@sentinelx.local'),
                            const SizedBox(width: 6),
                            _buildRolePill('Analyst', 'analyst@sentinelx.local'),
                            const SizedBox(width: 6),
                            _buildRolePill('User', 'user@sentinelx.local'),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Email
                        _SentinelTextField(
                          controller: _emailCtrl,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _SentinelTextField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: SentinelColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            if (v.length < 8) return 'Password must be at least 8 characters';
                            return null;
                          },
                          onFieldSubmitted: (_) => _handleLogin(),
                        ),

                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SentinelColors.threatCritical.withValues(alpha: 0.1),
                              borderRadius: SentinelRadius.smAll,
                              border: Border.all(
                                color: SentinelColors.threatCritical.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: SentinelColors.threatCritical, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: SentinelTypography.bodySmall.copyWith(
                                      color: SentinelColors.threatCritical,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SentinelColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: SentinelRadius.smAll,
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'AUTHENTICATE & ENTER',
                                    style: SentinelTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'SentinelX v0.1.0 • Restricted System Access • RBAC Protected',
                  style: SentinelTypography.labelSmall.copyWith(
                    color: SentinelColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRolePill(String role, String email) {
    final isSelected = _emailCtrl.text.trim() == email;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _emailCtrl.text = email;
            _passwordCtrl.text = 'ChangeMe!2024';
          });
        },
        borderRadius: SentinelRadius.smAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? SentinelColors.primary.withValues(alpha: 0.25)
                : SentinelColors.bgSurface,
            borderRadius: SentinelRadius.smAll,
            border: Border.all(
              color: isSelected ? SentinelColors.primary : SentinelColors.divider,
            ),
          ),
          child: Text(
            role,
            style: SentinelTypography.labelSmall.copyWith(
              color: isSelected ? SentinelColors.accent : SentinelColors.textTertiary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reusable Styled TextField ─────────────────────────────────────────────

class _SentinelTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const _SentinelTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: SentinelTypography.bodyMedium.copyWith(color: SentinelColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: SentinelTypography.bodySmall.copyWith(color: SentinelColors.textTertiary),
        prefixIcon: Icon(icon, color: SentinelColors.textTertiary, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: SentinelColors.bgSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: SentinelRadius.smAll,
          borderSide: const BorderSide(color: SentinelColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SentinelRadius.smAll,
          borderSide: const BorderSide(color: SentinelColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: SentinelRadius.smAll,
          borderSide: const BorderSide(color: SentinelColors.threatCritical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: SentinelRadius.smAll,
          borderSide: const BorderSide(color: SentinelColors.threatCritical, width: 2),
        ),
        errorStyle: SentinelTypography.labelSmall.copyWith(color: SentinelColors.threatCritical),
      ),
    );
  }
}
