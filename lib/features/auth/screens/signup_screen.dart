import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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
      final response = await _authRepository.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session == null) {
        // Email confirmation is enabled on the Supabase project. The
        // code-entry screen (VerifyEmailScreen) needs custom SMTP to
        // put a code in the email at all -- until that's set up, the
        // emailed link is the only working path, so that's what's
        // surfaced here.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email to confirm your account, then log in.'),
          ),
        );
      }
      // Pop back to reveal AuthGate either way -- if a session came back
      // immediately, its auth-state stream has already updated and it will
      // show ProfileGate as soon as this screen is off the stack.
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
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
            padding: const EdgeInsets.only(top: 10, bottom: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopBar(
                  eyebrow: 'GET STARTED',
                  title: 'Create your account',
                ),
                FieldLabel('Email address', topPadding: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
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
                FieldLabel('Password', topPadding: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'At least 6 characters',
                      prefixIcon: Icon(
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
                  label: 'Create account',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const FootNote(
                  'Next you will pick whether you are here to hire or to work.',
                  icon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
