import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../profile_repository.dart';
import 'technician_home_placeholder.dart';

class TechnicianProfileSetupScreen extends StatefulWidget {
  const TechnicianProfileSetupScreen({super.key});

  @override
  State<TechnicianProfileSetupScreen> createState() =>
      _TechnicianProfileSetupScreenState();
}

class _TechnicianProfileSetupScreenState
    extends State<TechnicianProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _skillsController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _profileRepository = ProfileRepository();

  File? _kycDocument;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _skillsController.dispose();
    _serviceAreaController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickKycDocument() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _kycDocument = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kycDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload a KYC ID document photo')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final profile = await _profileRepository.createProfile(
        role: 'technician',
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );
      final documentPath =
          await _profileRepository.uploadKycDocument(_kycDocument!);
      await _profileRepository.upsertTechnicianDetails(
        skills: _skillsController.text.trim(),
        serviceArea: _serviceAreaController.text.trim(),
      );
      await _profileRepository.upsertTechnicianKyc(
        idNumber: _idNumberController.text.trim(),
        documentPath: documentPath,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TechnicianHomePlaceholder(profile: profile),
        ),
      );
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
      appBar: AppBar(title: const Text('Your details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                Text('Work details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _skillsController,
                  decoration: const InputDecoration(
                    labelText: 'Skills',
                    hintText: 'e.g. Electrician, AC Repair',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serviceAreaController,
                  decoration: const InputDecoration(
                    labelText: 'Service area',
                    hintText: 'e.g. Koramangala, Bangalore',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                Text('KYC', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _idNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Government ID number',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickKycDocument,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _kycDocument == null
                        ? 'Upload ID document photo'
                        : 'Photo selected - tap to change',
                  ),
                ),
                if (_kycDocument != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_kycDocument!, height: 120, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
