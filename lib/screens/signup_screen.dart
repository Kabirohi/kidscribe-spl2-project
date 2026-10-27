import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../services/password_rules.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_shell.dart';
import '../widgets/common.dart';

/// Sign up (SRS FR_1). Sends AuthSignUpRequested to AuthBloc.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _role = 'Parent';
  bool _showPassword = false;

  final List<Map<String, dynamic>> _roles = [
    {'value': 'Parent', 'icon': Icons.family_restroom, 'color': AppColors.primary},
    {'value': 'Teacher', 'icon': Icons.school, 'color': AppColors.secondary},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _signup() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthSignUpRequested(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
          role: _role,
          school: _schoolController.text,
        ));
  }

  void _showSnack(String msg, Color color) =>
      showKidSnack(context, msg, color: color);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          _showSnack(state.errorMessage!, AppColors.error);
          context.read<AuthBloc>().add(const AuthErrorCleared());
        }
        // Signed up: AuthGate below already shows the home screen, so
        // we only need to close this screen.
        if (state.status == AuthStatus.authenticated) {
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      },
      builder: (context, state) {
        return AuthShell(
          showBack: true,
          title: 'Join KidScribe',
          subtitle: 'A grown-up makes the account. Children practise on '
              'your tablet.',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoleSelector(),
                const SizedBox(height: 22),
                _buildField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                // Teachers must name their school (SRS US_2).
                if (_role == 'Teacher') ...[
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _schoolController,
                    label: 'School / Institute name',
                    icon: Icons.location_city_rounded,
                    validator: (v) => _role == 'Teacher' &&
                            (v == null || v.trim().isEmpty)
                        ? 'Please enter your school or institute name'
                        : null,
                  ),
                ],
                const SizedBox(height: 14),
                _buildField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: !_showPassword,
                  onChanged: (_) => setState(() {}),
                  suffix: IconButton(
                    icon: Icon(
                        _showPassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: AppColors.textMuted),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  // SRS FR_1 / US_3 - the rules live in PasswordRules.
                  validator: PasswordRules.validate,
                ),
                const SizedBox(height: 12),
                _buildPasswordRules(),
                const SizedBox(height: 14),
                _buildField(
                  controller: _confirmController,
                  label: 'Confirm password',
                  icon: Icons.lock_outline_rounded,
                  obscure: !_showPassword,
                  validator: (v) => PasswordRules.validateConfirm(
                      v, _passwordController.text),
                ),
                const SizedBox(height: 28),
                KidButton('Create Account',
                    busy: state.submitting, onPressed: _signup),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The password rules, always visible, ticking green as the user types.
  Widget _buildPasswordRules() {
    Widget rule(String text, bool ok) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: ok ? AppColors.success : const Color(0xFFB9B5D3)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: kid(14,
                        weight: FontWeight.w700,
                        color: ok ? AppColors.success : AppColors.textMuted)),
              ),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (text, ok)
              in PasswordRules.checklist(_passwordController.text))
            rule(text, ok),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am a...', style: kid(18, weight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(
          children: _roles.map((r) {
            final isSelected = _role == r['value'];
            final color = r['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _role = r['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.10)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 2.5),
                  ),
                  child: Column(
                    children: [
                      KidIconBadge(r['icon'] as IconData,
                          color: isSelected ? color : const Color(0xFFB9B5D3),
                          size: 52),
                      const SizedBox(height: 10),
                      Text(r['value'] as String,
                          style: kid(16,
                              weight: FontWeight.w900,
                              color: isSelected
                                  ? AppColors.textDark
                                  : AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      style: kid(17, weight: FontWeight.w700),
      decoration:
          KidInput.decoration(label: label, icon: icon, suffix: suffix),
      validator: validator,
    );
  }
}
