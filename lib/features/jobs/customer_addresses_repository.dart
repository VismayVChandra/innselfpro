import '../../core/supabase_client.dart';
import '../../models/customer_address.dart';

class CustomerAddressesRepository {
  /// Every saved address for the caller, default first. Backfills a
  /// single "Home" entry from profiles.address the first time this is
  /// called for a customer with none saved yet -- profiles.address
  /// already existed before this feature, so a repeat customer isn't
  /// starting from zero.
  Future<List<CustomerAddress>> fetchMyAddresses() async {
    final uid = supabase.auth.currentUser!.id;
    var data = await supabase
        .from('customer_addresses')
        .select()
        .eq('customer_id', uid)
        .order('is_default', ascending: false)
        .order('created_at');
    var addresses = (data as List)
        .map((e) => CustomerAddress.fromMap(e as Map<String, dynamic>))
        .toList();
    if (addresses.isEmpty) {
      final profile =
          await supabase.from('profiles').select('address').eq('id', uid).maybeSingle();
      final existingAddress = (profile?['address'] as String?)?.trim();
      if (existingAddress != null && existingAddress.isNotEmpty) {
        await addAddress(label: 'Home', address: existingAddress, isDefault: true);
        data = await supabase
            .from('customer_addresses')
            .select()
            .eq('customer_id', uid)
            .order('is_default', ascending: false)
            .order('created_at');
        addresses = (data as List)
            .map((e) => CustomerAddress.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    }
    return addresses;
  }

  Future<void> addAddress({
    required String label,
    required String address,
    String? pincode,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    if (isDefault) {
      await supabase
          .from('customer_addresses')
          .update({'is_default': false}).eq('customer_id', uid);
    }
    await supabase.from('customer_addresses').insert({
      'customer_id': uid,
      'label': label,
      'address': address,
      'pincode': ?pincode,
      'lat': ?lat,
      'lng': ?lng,
      'is_default': isDefault,
    });
  }

  Future<void> setDefault(String addressId) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('customer_addresses')
        .update({'is_default': false}).eq('customer_id', uid);
    await supabase
        .from('customer_addresses')
        .update({'is_default': true}).eq('id', addressId);
  }

  Future<void> deleteAddress(String addressId) async {
    await supabase.from('customer_addresses').delete().eq('id', addressId);
  }
}
