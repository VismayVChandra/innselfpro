import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../models/kyc_submission.dart';
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
    String serviceArea = '',
    double? baseLat,
    double? baseLng,
    int? serviceRadiusKm,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('technician_details').upsert({
      'profile_id': uid,
      'service_area': serviceArea,
      'base_lat': ?baseLat,
      'base_lng': ?baseLng,
      'service_radius_km': ?serviceRadiusKm,
    });
  }

  /// Flips whether this technician shows up in new-job alerts and stays
  /// pickable for rebook/direct-request (migration 012) -- e.g. mid-job,
  /// asleep, or away for the week.
  Future<void> setAvailability(bool isAvailable) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('technician_details')
        .update({'is_available': isAvailable}).eq('profile_id', uid);
  }

  /// Whether a specific technician (not necessarily the caller) is
  /// currently available -- via a SECURITY DEFINER function since
  /// technician_details itself is owner-only. Used to grey out "Book
  /// again" on a technician who's gone unavailable since a past job.
  Future<bool> fetchTechnicianAvailability(String technicianId) async {
    final result = await supabase.rpc(
      'is_technician_available',
      params: {'p_technician_id': technicianId},
    );
    return result as bool? ?? true;
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
    required String documentType,
    required String idNumber,
    required String documentPath,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('technician_kyc').upsert({
      'profile_id': uid,
      'document_type': documentType,
      'id_number': idNumber.trim(),
      'id_document_url': documentPath,
      // Resubmitting after a rejection puts the record back in the
      // queue -- otherwise a rejected technician could fix their
      // document and still show as rejected forever.
      'status': 'pending',
      'rejection_reason': null,
    });
  }

  /// The caller's own KYC record (migration 015), so a technician can
  /// see whether they're pending, verified, or rejected -- and why.
  /// Null when they haven't submitted one at all.
  Future<KycSubmission?> fetchMyKyc() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('technician_kyc')
        .select()
        .eq('profile_id', uid)
        .maybeSingle();
    if (data == null) return null;
    return KycSubmission.fromMap(data);
  }

  /// Which of these profiles carry the verified badge, in one round
  /// trip -- profiles_select_all already exposes this column to any
  /// authenticated user, so no new policy is involved.
  Future<Set<String>> fetchVerifiedProfileIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await supabase
        .from('profiles')
        .select('id, is_verified')
        .inFilter('id', ids)
        .eq('is_verified', true);
    return {
      for (final row in rows as List) (row as Map<String, dynamic>)['id'] as String,
    };
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
