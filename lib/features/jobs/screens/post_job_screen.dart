import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/category.dart';
import '../jobs_repository.dart';
import '../widgets/category_grid.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key, this.initialCategory});

  /// Pre-selected when the customer arrived by tapping a tile in the
  /// home screen's "Book a service" grid.
  final Category? initialCategory;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _jobsRepository = JobsRepository();

  late final Future<List<Category>> _categoriesFuture;
  int? _selectedCategoryId;
  File? _photo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _jobsRepository.fetchCategories();
    _selectedCategoryId = widget.initialCategory?.id;
    _descriptionController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
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

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the kind of help you need first')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _jobsRepository.createJob(
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        photo: _photo,
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
                      onTap: (category) => setState(
                        () => _selectedCategoryId = category.id,
                      ),
                    );
                  },
                ),
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
                const FieldLabel('Add a photo', topPadding: 23),
                _PhotoPicker(
                  photo: _photo,
                  onPick: _pickPhoto,
                  onClear: () => setState(() => _photo = null),
                ),
                const FieldLabel('Where should they come?', topPadding: 23),
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

/// Optional job photo: an invitation while empty, a preview once picked.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.onPick,
    required this.onClear,
  });

  final File? photo;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return AppCard(
        onTap: onPick,
        radius: 17,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            const SoftIcon(Icons.photo_camera_outlined, size: 39, iconSize: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add a photo', style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Optional, but it helps pros quote accurately.',
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
              photo!,
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
                _PhotoAction(icon: Icons.edit_outlined, onTap: onPick),
                const SizedBox(width: 8),
                _PhotoAction(icon: Icons.close_rounded, onTap: onClear),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({required this.icon, required this.onTap});

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
