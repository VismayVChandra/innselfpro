import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../auth_repository.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Navigation happens automatically via the AuthGate's session stream.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 22, bottom: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandMark(),
                const SizedBox(height: 26),
                const DarkPanel(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WELCOME BACK',
                        style: TextStyle(
                          color: AppColors.onPanelKicker,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Your home,\nlooked after.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1.16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                      SizedBox(height: 11),
                      Text(
                        'Sign in to post a job or start bidding.',
                        style: TextStyle(
                          color: AppColors.onPanelMuted,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const FieldLabel('Email address', topPadding: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                ),
                const FieldLabel('Password', topPadding: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'At least 6 characters',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                          color: AppColors.mutedForeground,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        tooltip: _obscurePassword ? 'Show' : 'Hide',
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Log in',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          ),
                  child: const Text("New to InnSelf? Create an account"),
                ),
                const FootNote(
                  'Email and password only. We never post anything on your behalf.',
                  icon: Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The InnSelf wordmark with its tile, shown on the auth screens.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.home_rounded,
            size: 21,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 11),
        const Text(
          'InnSelf',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}
