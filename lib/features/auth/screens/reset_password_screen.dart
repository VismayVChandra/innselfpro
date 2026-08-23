import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../auth_repository.dart';

/// Rendered directly by AuthGate whenever the latest auth event is
/// AuthChangeEvent.passwordRecovery -- i.e. right after the user taps
/// the link from a resetPasswordForEmail email and the deep link hands
/// a live session back to the app. Setting a password here is what
/// actually consumes that session; there's no other way back to a
/// normal signed-in state from a recovery session.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authRepository.updatePassword(_passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
      // No manual navigation needed -- updateUser() itself fires
      // AuthChangeEvent.userUpdated, which moves AuthGate's own
      // StreamBuilder off the passwordRecovery branch and on to
      // ProfileGate reactively, the same way every other auth
      // transition in this app already works.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update password: $e')),
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
                const TopBar(eyebrow: 'ACCOUNT', title: 'Set a new password'),
                const FieldLabel('New password', topPadding: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
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
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 19,
                          color: AppColors.mutedForeground,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                ),
                const FieldLabel('Confirm password', topPadding: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _confirmController,
                    obscureText: _obscure,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type it again',
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    validator: (v) =>
                        (v != _passwordController.text) ? "Passwords don't match" : null,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Update password',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
