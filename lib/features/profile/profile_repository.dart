import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../models/profile.dart';
import '../../models/technician_details.dart';

class ProfileRepository {
  Future<Profile?> fetchMyProfile() async {
    final uid = supabase.auth.currentUser!.id;
    final data =
        await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  /// Looks up any user's basic profile (name + phone) by id. Safe under
  /// the current RLS -- profiles_select_all already allows any
  /// authenticated user to read any profile row -- used to surface a
  /// technician's or customer's contact details once they're matched on
  /// a job.
  Future<Profile?> fetchProfileById(String id) async {
    final data =
        await supabase.from('profiles').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<TechnicianDetails?> fetchMyTechnicianDetails() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('technician_details')
        .select()
        .eq('profile_id', uid)
        .maybeSingle();
    if (data == null) return null;
    return TechnicianDetails.fromMap(data);
  }

  Future<Profile> createProfile({
    required String role,
    required String fullName,
    required String phone,
    String? address,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('profiles')
        .insert({
          'id': uid,
          'role': role,
          'full_name': fullName,
          'phone': phone,
          'address': address,
        })
        .select()
        .single();
    return Profile.fromMap(data);
  }

  /// Updates the caller's own name/phone/address. Uses the existing
  /// profiles_update_own RLS policy -- no migration needed.
  Future<Profile> updateProfile({
    required String fullName,
    required String phone,
    String? address,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('profiles')
        .update({
          'full_name': fullName,
          'phone': phone,
          'address': address,
        })
        .eq('id', uid)
        .select()
        .single();
    return Profile.fromMap(data);
  }

  Future<void> upsertTechnicianDetails({
    required String serviceArea,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('technician_details').upsert({
      'profile_id': uid,
      'service_area': serviceArea,
    });
  }

  /// Category ids this technician has marked as a skill.
  Future<Set<int>> fetchMySkillCategoryIds() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('technician_skills')
        .select('category_id')
        .eq('profile_id', uid);
    return (data as List)
        .map((e) => (e as Map<String, dynamic>)['category_id'] as int)
        .toSet();
  }

  /// Replaces this technician's full skill set with exactly the given
  /// categories -- simpler and safer than diffing add/remove, and this
  /// is always called with the complete intended set from a multi-select
  /// form, never a partial update.
  Future<void> setMySkillCategories(Set<int> categoryIds) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('technician_skills').delete().eq('profile_id', uid);
    if (categoryIds.isEmpty) return;
    await supabase.from('technician_skills').insert([
      for (final categoryId in categoryIds)
        {'profile_id': uid, 'category_id': categoryId},
    ]);
  }

  Future<void> upsertTechnicianKyc({
    required String idNumber,
    required String documentPath,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('technician_kyc').upsert({
      'profile_id': uid,
      'id_number': idNumber,
      'id_document_url': documentPath,
    });
  }

  /// Uploads to the private technician-kyc bucket under the user's own
  /// folder (required by the storage RLS policy) and returns the storage
  /// path -- not a public URL, since the bucket is private.
  Future<String> uploadKycDocument(File file) async {
    final uid = supabase.auth.currentUser!.id;
    final ext = file.path.split('.').last;
    final path = '$uid/kyc.$ext';
    await supabase.storage.from('technician-kyc').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }
}
