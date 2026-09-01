import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authRepository.resetPasswordForEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset email: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(eyebrow: 'ACCOUNT', title: 'Reset your password'),
              if (_sent)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: EmptyView(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Check your email',
                    message:
                        'We sent a reset link to ${_emailController.text.trim()}. Open it on this '
                        'phone to set a new password.',
                  ),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: kTextGutter),
                        child: Text(
                          "Enter the email you signed up with and we'll send you a link to set a "
                          'new password.',
                          style: AppText.bodyMuted,
                        ),
                      ),
                      FieldLabel('Email address', topPadding: 20),
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
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Send reset link',
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
