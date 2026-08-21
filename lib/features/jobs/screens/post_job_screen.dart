import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../core/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/category.dart';
import '../../../models/customer_address.dart';
import '../customer_addresses_repository.dart';
import '../jobs_repository.dart';
import '../widgets/category_grid.dart';
import '../widgets/job_photos_picker.dart';
import '../widgets/price_guidance_hint.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({
    super.key,
    this.initialCategory,
    this.invitedTechnicianId,
    this.invitedTechnicianName,
    this.initialDescription,
    this.initialLocation,
  });

  /// Pre-selected when the customer arrived by tapping a tile in the
  /// home screen's "Book a service" grid.
  final Category? initialCategory;

  /// Set when the customer arrived via "Book again" from a past job --
  /// this request becomes invite-only to that one technician instead of
  /// open to everyone.
  final String? invitedTechnicianId;
  final String? invitedTechnicianName;

  /// Set when arriving via "Repost" on an expired request (wave 6.3) --
  /// prefills the form so the customer isn't retyping everything, but
  /// they still submit a genuinely new job, not an update to the old one.
  final String? initialDescription;
  final String? initialLocation;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _jobsRepository = JobsRepository();
  final _addressesRepository = CustomerAddressesRepository();
  final _locationService = LocationService();

  late final Future<List<Category>> _categoriesFuture;
  late final Future<List<CustomerAddress>> _addressesFuture;
  int? _selectedCategoryId;
  Future<({double average, double min, double max, int count})?>? _priceGuidanceFuture;
  List<File> _photos = [];
  bool _isLoading = false;
  bool _isLocating = false;
  double? _lat;
  double? _lng;
  String? _selectedAddressId;

  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _jobsRepository.fetchCategories();
    _addressesFuture = _addressesRepository.fetchMyAddresses();
    _selectedCategoryId = widget.initialCategory?.id;
    if (_selectedCategoryId != null) {
      _priceGuidanceFuture = _jobsRepository.fetchPriceGuidance(_selectedCategoryId!);
    }
    _descriptionController.text = widget.initialDescription ?? '';
    _locationController.text = widget.initialLocation ?? '';
    _descriptionController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _pickAddress(CustomerAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _locationController.text = address.address;
      _pincodeController.text = address.pincode ?? '';
      _lat = address.lat;
      _lng = address.lng;
    });
  }

  void _pickManualAddress() {
    setState(() {
      _selectedAddressId = null;
      _locationController.clear();
      _pincodeController.clear();
      _lat = null;
      _lng = null;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final location = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      if (location != null) {
        _lat = location.lat;
        _lng = location.lng;
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          location == null
              ? 'Could not get your location -- check location permission is granted'
              : 'Location captured',
        ),
      ),
    );
  }

  /// Drives the three-segment progress bar at the top of the form.
  void _onFieldChanged() => setState(() {});

  int get _completedSteps {
    var steps = 0;
    if (_selectedCategoryId != null) steps++;
    if (_descriptionController.text.trim().length >= 8) steps++;
    if (_locationController.text.trim().isNotEmpty) steps++;
    return steps;
  }

  DateTime? get _scheduledFor {
    if (!_isScheduled || _scheduledDate == null) return null;
    final time = _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  static const _maxPhotos = 5;

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty) return;
    setState(() {
      _photos = [..._photos, ...picked.take(remaining).map((x) => File(x.path))];
    });
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the kind of help you need first')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_isScheduled && _scheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date for the visit, or switch to "As soon as possible"')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _jobsRepository.createJob(
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        photos: _photos,
        scheduledFor: _scheduledFor,
        invitedTechnicianId: widget.invitedTechnicianId,
        pincode: _pincodeController.text.trim(),
        lat: _lat,
        lng: _lng,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post job: $e')),
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
                const TopBar(
                  eyebrow: 'NEW REQUEST',
                  title: "Tell us what's wrong",
                ),
                if (widget.invitedTechnicianId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_pin_circle_outlined,
                            size: 18,
                            color: AppColors.accentForeground,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.invitedTechnicianName == null
                                  ? 'Requesting this technician directly -- other technicians won\'t see this job.'
                                  : 'Requesting ${widget.invitedTechnicianName} directly -- other technicians won\'t see this job.',
                              style: AppText.meta.copyWith(
                                color: AppColors.accentForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _ProgressBar(completed: _completedSteps),
                const FieldLabel('What do you need help with?'),
                FutureBuilder<List<Category>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorView(
                        message:
                            'Could not load categories: ${snapshot.error}',
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView(height: 140);
                    }
                    return CategoryGrid(
                      categories: snapshot.data!,
                      selectedId: _selectedCategoryId,
                      onTap: (category) => setState(() {
                        _selectedCategoryId = category.id;
                        _priceGuidanceFuture =
                            _jobsRepository.fetchPriceGuidance(category.id);
                      }),
                    );
                  },
                ),
                if (_priceGuidanceFuture != null) ...[
                  const SizedBox(height: 12),
                  PriceGuidanceHint(future: _priceGuidanceFuture!),
                ],
                const FieldLabel('Describe the problem', topPadding: 27),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppText.body.copyWith(fontSize: 13, height: 1.5),
                    decoration: const InputDecoration(
                      hintText:
                          'For example: the kitchen tap is leaking from the base...',
                    ),
                    validator: (v) => (v == null || v.trim().length < 8)
                        ? 'Add a little more detail'
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(kTextGutter, 7, kTextGutter, 0),
                  child: Text(
                    'The more you share, the better the match.',
                    style: AppText.bodyMuted,
                  ),
                ),
                FieldLabel(
                  _photos.isEmpty ? 'Add photos' : 'Photos (${_photos.length}/$_maxPhotos)',
                  topPadding: 23,
                ),
                JobPhotosPicker(
                  photos: _photos,
                  maxPhotos: _maxPhotos,
                  onAdd: _pickPhotos,
                  onRemove: (i) => setState(() => _photos = [..._photos]..removeAt(i)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(kTextGutter, 7, kTextGutter, 0),
                  child: Text(
                    'Optional, but it helps pros quote accurately.',
                    style: AppText.bodyMuted,
                  ),
                ),
                const FieldLabel('Where should they come?', topPadding: 23),
                FutureBuilder<List<CustomerAddress>>(
                  future: _addressesFuture,
                  builder: (context, snapshot) {
                    final addresses = snapshot.data ?? const <CustomerAddress>[];
                    if (addresses.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: kGutter),
                          children: [
                            for (final address in addresses) ...[
                              ChoicePill(
                                label: address.label,
                                selected: _selectedAddressId == address.id,
                                onTap: () => _pickAddress(address),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ChoicePill(
                              label: 'Add new',
                              selected: _selectedAddressId == null &&
                                  _locationController.text.isEmpty,
                              onTap: _pickManualAddress,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.words,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Koramangala, Bangalore',
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tell us where to send them'
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextFormField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Pincode',
                      counterText: '',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length != 6) ? '6-digit pincode' : null,
                  ),
                ),
                OutlineButton(
                  label: _lat == null ? 'Use current location' : 'Location set',
                  icon: _lat == null ? Icons.my_location_rounded : Icons.check_circle_outline,
                  isLoading: _isLocating,
                  onPressed: _useCurrentLocation,
                ),
                const FieldLabel('When do you need this done?', topPadding: 23),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ToggleOption(
                          label: 'As soon as possible',
                          selected: !_isScheduled,
                          onTap: () => setState(() => _isScheduled = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleOption(
                          label: 'Schedule for later',
                          selected: _isScheduled,
                          onTap: () => setState(() => _isScheduled = true),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isScheduled) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kGutter),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PickerField(
                            icon: Icons.calendar_today_outlined,
                            label: _scheduledDate == null
                                ? 'Pick a date'
                                : formatShortDate(_scheduledDate!),
                            filled: _scheduledDate != null,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PickerField(
                            icon: Icons.access_time_outlined,
                            label: _scheduledTime == null
                                ? 'Pick a time'
                                : _scheduledTime!.format(context),
                            filled: _scheduledTime != null,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 31),
                PrimaryButton(
                  label: 'Find my pro',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const FootNote(
                  'Your address is only shared with technicians who bid on this job.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three segments that fill in as the form gets answered.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kTextGutter, 0, kTextGutter, 29),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: i < completed ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centred two-option toggle for "as soon as possible" vs "schedule for
/// later". Similar to [ChoicePill] but sized to fill an [Expanded] slot
/// with its label centred, rather than sized to its content.
class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.foreground : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.foreground : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.background : AppColors.foreground,
          ),
        ),
      ),
    );
  }
}

/// Tappable field that opens a date or time picker, showing the chosen
/// value once picked.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 15,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: filled ? AppColors.foreground : AppColors.mutedForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: filled ? AppColors.foreground : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

