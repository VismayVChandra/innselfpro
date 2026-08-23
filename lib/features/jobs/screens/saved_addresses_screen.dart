import 'package:flutter/material.dart';

import '../../../core/location_service.dart';
import '../../../core/widgets/location_disclosure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/customer_address.dart';
import '../customer_addresses_repository.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _repository = CustomerAddressesRepository();
  late Future<List<CustomerAddress>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchMyAddresses();
  }

  void _refresh() => setState(() => _future = _repository.fetchMyAddresses());

  Future<void> _addAddress() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAddressSheet(),
    );
    if (added == true) _refresh();
  }

  Future<void> _delete(CustomerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text('"${address.label}" will be removed from your saved addresses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteAddress(address.id);
    _refresh();
  }

  Future<void> _setDefault(CustomerAddress address) async {
    await _repository.setDefault(address.id);
    _refresh();
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
              const TopBar(eyebrow: 'ACCOUNT', title: 'Saved addresses'),
              FutureBuilder<List<CustomerAddress>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: 'Could not load addresses: ${snapshot.error}',
                      onRetry: _refresh,
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  final addresses = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (addresses.isEmpty)
                        const EmptyView(
                          icon: Icons.location_on_outlined,
                          title: 'No saved addresses yet',
                          message: 'Add one so you never retype it when posting a job.',
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: kGutter),
                          child: Column(
                            children: [
                              for (final address in addresses)
                                _AddressRow(
                                  address: address,
                                  onSetDefault: () => _setDefault(address),
                                  onDelete: () => _delete(address),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      OutlineButton(
                        label: 'Add a new address',
                        icon: Icons.add_location_alt_outlined,
                        onPressed: _addAddress,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.onSetDefault,
    required this.onDelete,
  });

  final CustomerAddress address;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 19,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        borderColor: address.isDefault ? AppColors.primary : AppColors.border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIcon(
              address.isDefault ? Icons.star_rounded : Icons.location_on_outlined,
              background: address.isDefault ? AppColors.accent : AppColors.secondary,
              size: 40,
              iconSize: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(address.label, style: AppText.cardTitle),
                      if (address.isDefault) ...[
                        const SizedBox(width: 6),
                        Text('DEFAULT', style: AppText.microLabel.copyWith(color: AppColors.primary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(address.address, style: AppText.bodyMuted.copyWith(fontSize: 11)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!address.isDefault)
                        TextButton(
                          onPressed: onSetDefault,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Set as default'),
                        ),
                      const Spacer(),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 19),
                        color: AppColors.destructive,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding one address -- kept minimal (label + address
/// text, optional pincode, optional "use my current location") rather
/// than a full pushed screen, since it's a short one-shot form.
class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet();

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _repository = CustomerAddressesRepository();
  final _locationService = LocationService();
  double? _lat;
  double? _lng;
  bool _isLocating = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (!await confirmLocationUse(context, _locationService) || !mounted) return;
    setState(() => _isLocating = true);
    final location = await _locationService.getCurrentLocation();
    if (location == null) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get your location -- check location permission is granted'),
        ),
      );
      return;
    }
    final resolved = await _locationService.reverseGeocode(location.lat, location.lng);
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _lat = location.lat;
      _lng = location.lng;
      if (resolved?.address != null) _addressController.text = resolved!.address!;
      if (resolved?.pincode != null) _pincodeController.text = resolved!.pincode!;
    });
  }

  Future<void> _save() async {
    if (_labelController.text.trim().isEmpty || _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give it a label and the address')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _repository.addAddress(
        label: _labelController.text.trim(),
        address: _addressController.text.trim(),
        pincode: _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
        lat: _lat,
        lng: _lng,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save address: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add an address', style: AppText.display.copyWith(fontSize: 19)),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Label, e.g. Home, Office'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Full address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(hintText: 'Pincode (optional)', counterText: ''),
            ),
            OutlineButton(
              label: _lat == null ? 'Use current location' : 'Location set',
              icon: _lat == null ? Icons.my_location_rounded : Icons.check_circle_outline,
              margin: EdgeInsets.zero,
              isLoading: _isLocating,
              onPressed: _useCurrentLocation,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save address',
              margin: EdgeInsets.zero,
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
