import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../auth_repository.dart';

/// Shown right after signup when the project has email confirmation
/// enabled -- lets the user type the 6-digit code from the confirmation
/// email instead of clicking its link, which avoids the app having no
/// working web redirect target to land on.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code from the email')),
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await _authRepository.verifySignupOtp(email: widget.email, token: code);
      if (!mounted) return;
      // Verification signs the user in -- AuthGate's session stream
      // reacts on its own, so just clear this screen and signup off
      // the stack to reveal it.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not verify: $e')),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await _authRepository.resendSignupOtp(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent a new code')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend code: $e')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
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
              TopBar(eyebrow: 'ALMOST THERE', title: 'Verify your email'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kTextGutter),
                child: Text(
                  'We sent a 6-digit code to ${widget.email}. Enter it below to confirm your account.',
                  style: AppText.bodyMuted,
                ),
              ),
              FieldLabel('Confirmation code', topPadding: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(fontSize: 22, letterSpacing: 10),
                  decoration: const InputDecoration(counterText: ''),
                  onSubmitted: (_) => _verify(),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Verify',
                isLoading: _isVerifying,
                onPressed: _verify,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _isResending ? null : _resend,
                child: Text(_isResending ? 'Sending...' : "Didn't get it? Resend code"),
              ),
              const FootNote(
                'You can also just tap the link in that email instead.',
                icon: Icons.link_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
