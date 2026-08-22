import 'package:flutter/material.dart';

import '../../../core/location_service.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../models/category.dart';
import '../../../models/profile.dart';
import '../../jobs/jobs_repository.dart';
import '../profile_repository.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/skills_selector.dart';

/// Lets a signed-in user change their name, phone and address -- plus
/// skills and service area for a technician. Both roles share this one
/// screen since the only difference is two extra fields.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  final Profile profile;

  /// Called with the freshly saved profile so the caller (a shell) can
  /// update what it hands to every tab.
  final ValueChanged<Profile> onSaved;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _profileRepository = ProfileRepository();
  final _locationService = LocationService();

  List<Category> _categories = [];
  final Set<int> _selectedSkillCategoryIds = {};
  bool _isLoadingDetails = true;
  bool _isSaving = false;
  bool _isLocating = false;
  Object? _loadError;
  double? _baseLat;
  double? _baseLng;
  String? _locationLabel;
  int _radiusKm = 10;

  bool get _isTechnician => widget.profile.isTechnician;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile.fullName;
    _phoneController.text = widget.profile.phone;
    _addressController.text = widget.profile.address ?? '';
    if (_isTechnician) {
      _loadTechnicianDetails();
    } else {
      _isLoadingDetails = false;
    }
  }

  Future<void> _loadTechnicianDetails() async {
    try {
      final categories = await JobsRepository().fetchCategories();
      final details = await _profileRepository.fetchMyTechnicianDetails();
      final skillIds = await _profileRepository.fetchMySkillCategoryIds();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedSkillCategoryIds
          ..clear()
          ..addAll(skillIds);
        _baseLat = details?.baseLat;
        _baseLng = details?.baseLng;
        _radiusKm = details?.serviceRadiusKm ?? 10;
        _isLoadingDetails = false;
      });
      // Best-effort label for an already-saved location -- purely a
      // readable confirmation, so a failure here shouldn't block the
      // rest of the form from loading.
      if (_baseLat != null && _baseLng != null) {
        final resolved = await _locationService.reverseGeocode(_baseLat!, _baseLng!);
        if (mounted && resolved?.address != null) {
          setState(() => _locationLabel = resolved!.address);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _isLoadingDetails = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _setLocation() async {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isTechnician && _selectedSkillCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one skill')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final updated = await _profileRepository.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (_isTechnician) {
        await _profileRepository.upsertTechnicianDetails(
          baseLat: _baseLat,
          baseLng: _baseLng,
          serviceRadiusKm: _radiusKm,
        );
        await _profileRepository.setMySkillCategories(_selectedSkillCategoryIds);
      }
      if (!mounted) return;
      widget.onSaved(updated);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save changes: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                const TopBar(eyebrow: 'ACCOUNT', title: 'Edit profile'),
                const FieldLabel('Full name', topPadding: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const FieldLabel('Phone number', topPadding: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.call_outlined, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const FieldLabel('Address', topPadding: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                if (_isTechnician) ...[
                  if (_loadError != null)
                    ErrorView(
                      message: 'Could not load your work details: $_loadError',
                      onRetry: () {
                        setState(() {
                          _isLoadingDetails = true;
                          _loadError = null;
                        });
                        _loadTechnicianDetails();
                      },
                    )
                  else if (_isLoadingDetails)
                    const LoadingView(height: 100)
                  else ...[
                    const SectionHeading(title: 'Your work'),
                    const FieldLabel('Skills'),
                    SkillsSelector(
                      categories: _categories,
                      selectedIds: _selectedSkillCategoryIds,
                      onToggle: (id) => setState(() {
                        if (!_selectedSkillCategoryIds.remove(id)) {
                          _selectedSkillCategoryIds.add(id);
                        }
                      }),
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
                  ],
                ],
                const SizedBox(height: 30),
                PrimaryButton(
                  label: 'Save changes',
                  isLoading: _isSaving,
                  onPressed: _isLoadingDetails ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
