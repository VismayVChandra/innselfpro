import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../models/profile.dart';
import '../profile_repository.dart';

class CustomerProfileSetupScreen extends StatefulWidget {
  const CustomerProfileSetupScreen({super.key, required this.onProfileCreated});

  final ValueChanged<Profile> onProfileCreated;

  @override
  State<CustomerProfileSetupScreen> createState() =>
      _CustomerProfileSetupScreenState();
}

class _CustomerProfileSetupScreenState
    extends State<CustomerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _profileRepository = ProfileRepository();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final profile = await _profileRepository.createProfile(
        role: 'customer',
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (!mounted) return;
      widget.onProfileCreated(profile);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
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
                TopBar(eyebrow: 'CUSTOMER', title: 'Your details'),
                FieldLabel('Full name', topPadding: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'As your technician should address you',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                FieldLabel('Phone number', topPadding: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'So your pro can reach you',
                      prefixIcon: Icon(
                        Icons.call_outlined,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    validator: (v) => normalisePhone(v ?? '') == null
                        ? 'Enter a valid 10-digit phone number'
                        : null,
                  ),
                ),
                FieldLabel('Address', topPadding: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.words,
                    style: AppText.body.copyWith(fontSize: 13, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'Flat, street, area, city',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 30),
                PrimaryButton(
                  label: 'Continue',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const FootNote(
                  'Your address is only shared with technicians who bid on your jobs.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
