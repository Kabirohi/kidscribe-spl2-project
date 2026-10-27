import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_shell.dart';
import '../widgets/common.dart';
import 'signup_screen.dart';

/// The login screen (SRS FR_2).
///
/// It sends an AuthLoginRequested event to AuthBloc and draws whatever
/// state comes back. It never calls Firebase itself.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthLoginRequested(
          email: _emailController.text,
          password: _passwordController.text,
        ));
  }

  void _showSnack(String msg, Color color) =>
      showKidSnack(context, msg, color: color);

  @override
  Widget build(BuildContext context) {
    // BlocConsumer = listen (show the error) + build (draw the screen).
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (a, b) => a.errorMessage != b.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          _showSnack(state.errorMessage!, AppColors.error);
          context.read<AuthBloc>().add(const AuthErrorCleared());
        }
      },
      builder: (context, state) {
        return AuthShell(
          title: 'Welcome back!',
          subtitle: 'Log in to keep practising.',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 28),
                KidButton('Log In',
                    busy: state.submitting, onPressed: _login),
                const SizedBox(height: 26),
                _buildSignupLink(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: kid(17, weight: FontWeight.w700),
      decoration: KidInput.decoration(
          label: 'Email', icon: Icons.email_outlined),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Please enter your email';
        if (!val.contains('@')) return 'Please enter a valid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_showPassword,
      style: kid(17, weight: FontWeight.w700),
      decoration: KidInput.decoration(
        label: 'Password',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          icon: Icon(
              _showPassword
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: AppColors.textMuted),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Please enter your password';
        return null;
      },
    );
  }

  Widget _buildSignupLink() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text("Don't have an account?",
                  style: kid(14, color: AppColors.textMuted)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        KidOutlineButton(
          'Create an account',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            );
          },
        ),
      ],
    );
  }
}
