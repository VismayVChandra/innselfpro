import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location_service.dart';
import '../../../core/widgets/location_disclosure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/category.dart';
import '../../../models/profile.dart';
import '../../jobs/jobs_repository.dart';
import '../profile_repository.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/skills_selector.dart';

class TechnicianProfileSetupScreen extends StatefulWidget {
  const TechnicianProfileSetupScreen({super.key, required this.onProfileCreated});

  final ValueChanged<Profile> onProfileCreated;

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
  final _idNumberController = TextEditingController();
  final _profileRepository = ProfileRepository();
  final _locationService = LocationService();
  late final Future<List<Category>> _categoriesFuture =
      JobsRepository().fetchCategories();

  static const _documentTypes = ['PAN', 'Voter ID', 'Driving Licence'];

  final Set<int> _selectedSkillCategoryIds = {};
  String? _documentType;
  File? _kycDocument;
  bool _isLoading = false;
  bool _isLocating = false;
  double? _baseLat;
  double? _baseLng;
  String? _locationLabel;
  int _radiusKm = 10;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _setLocation() async {
    if (!await confirmLocationUse(context, _locationService) || !mounted) return;
    setState(() => _isLocating = true);
    final location = await _locationService.getCurrentLocation();
    if (location == null) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location -- check location permission is granted')),
      );
      return;
    }
    final resolved = await _locationService.reverseGeocode(location.lat, location.lng);
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _baseLat = location.lat;
      _baseLng = location.lng;
      _locationLabel = resolved?.address;
    });
  }

  Future<void> _pickKycDocument() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _kycDocument = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkillCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one skill')),
      );
      return;
    }
    if (_documentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select which ID you\'re uploading')),
      );
      return;
    }
    // Belt-and-braces beyond the removed Aadhaar option: catches someone
    // who picks PAN/Voter ID/Driving Licence but types an Aadhaar-shaped
    // number anyway (by habit or by mistake).
    if (_idNumberController.text.replaceAll(RegExp(r'\D'), '').length == 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("That looks like an Aadhaar number -- we don't accept Aadhaar. "
              'Enter the number from your PAN, Voter ID, or Driving Licence instead.'),
        ),
      );
      return;
    }
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
        baseLat: _baseLat,
        baseLng: _baseLng,
        serviceRadiusKm: _radiusKm,
      );
      await _profileRepository.setMySkillCategories(_selectedSkillCategoryIds);
      await _profileRepository.upsertTechnicianKyc(
        documentType: _documentType!,
        idNumber: _idNumberController.text.trim(),
        documentPath: documentPath,
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

  Widget _field({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: capitalization,
        style: AppText.body.copyWith(fontSize: 13, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 20, color: AppColors.mutedForeground),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
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
                const TopBar(eyebrow: 'TECHNICIAN', title: 'Your details'),
                const FieldLabel('Full name', topPadding: 12),
                _field(
                  controller: _nameController,
                  hint: 'As it appears on your ID',
                  icon: Icons.person_outline_rounded,
                  capitalization: TextCapitalization.words,
                ),
                const FieldLabel('Phone number', topPadding: 20),
                _field(
                  controller: _phoneController,
                  hint: 'So customers can reach you',
                  icon: Icons.call_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const FieldLabel('Address', topPadding: 20),
                _field(
                  controller: _addressController,
                  hint: 'Flat, street, area, city',
                  maxLines: 3,
                  capitalization: TextCapitalization.words,
                ),
                const SectionHeading(title: 'Your work'),
                const FieldLabel('Skills'),
                FutureBuilder<List<Category>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Could not load categories: ${snapshot.error}',
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView(height: 60);
                    }
                    return SkillsSelector(
                      categories: snapshot.data!,
                      selectedIds: _selectedSkillCategoryIds,
                      onToggle: (id) => setState(() {
                        if (!_selectedSkillCategoryIds.remove(id)) {
                          _selectedSkillCategoryIds.add(id);
                        }
                      }),
                    );
                  },
                ),
                const FieldLabel('Service area', topPadding: 20),
                ServiceRadiusPicker(
                  hasLocation: _baseLat != null && _baseLng != null,
                  isLocating: _isLocating,
                  radiusKm: _radiusKm,
                  locationLabel: _locationLabel,
                  onSetLocation: _setLocation,
                  onRadiusChanged: (value) => setState(() => _radiusKm = value.round()),
                ),
                const SectionHeading(title: 'Identity check'),
                const FieldLabel('Which ID are you uploading?'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in _documentTypes)
                        ChoicePill(
                          label: type,
                          selected: _documentType == type,
                          onTap: () => setState(() => _documentType = type),
                        ),
                    ],
                  ),
                ),
                const FieldLabel('ID number', topPadding: 16),
                _field(
                  controller: _idNumberController,
                  hint: 'As printed on the document',
                  icon: Icons.badge_outlined,
                  capitalization: TextCapitalization.characters,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(kTextGutter, 7, kTextGutter, 0),
                  child: Text(
                    "We don't accept Aadhaar -- make sure the photo you upload doesn't show an "
                    'Aadhaar card either.',
                    style: AppText.bodyMuted,
                  ),
                ),
                const SizedBox(height: 16),
                _KycUpload(
                  document: _kycDocument,
                  onPick: _pickKycDocument,
                  onClear: () => setState(() => _kycDocument = null),
                ),
                const SizedBox(height: 30),
                PrimaryButton(
                  label: 'Continue',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const FootNote(
                  'Your ID is stored privately and is never shown to customers.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// KYC document: a prompt card while empty, a preview once chosen.
class _KycUpload extends StatelessWidget {
  const _KycUpload({
    required this.document,
    required this.onPick,
    required this.onClear,
  });

  final File? document;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (document == null) {
      return AppCard(
        onTap: onPick,
        radius: 17,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            const SoftIcon(Icons.upload_file_outlined, size: 39, iconSize: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload your ID photo', style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Required. A clear photo of the document above.',
                    style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.file(
              document!,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                _ImageAction(icon: Icons.edit_outlined, onTap: onPick),
                const SizedBox(width: 8),
                _ImageAction(icon: Icons.close_rounded, onTap: onClear),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageAction extends StatelessWidget {
  const _ImageAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: AppColors.foreground),
        ),
      ),
    );
  }
}
