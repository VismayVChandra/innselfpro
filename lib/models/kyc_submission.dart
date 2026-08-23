/// One technician's KYC record. The technician sees their own via
/// [KycStatus]; an admin sees everyone's through admin_list_kyc, which
/// joins the applicant's name and phone on (migration 015).
class KycSubmission {
  final String profileId;
  final String fullName;
  final String phone;
  final String? documentType;
  final String idNumber;
  final String idDocumentUrl;
  final String status;
  final String? rejectionReason;
  final DateTime submittedAt;

  const KycSubmission({
    required this.profileId,
    required this.fullName,
    required this.phone,
    this.documentType,
    required this.idNumber,
    required this.idDocumentUrl,
    required this.status,
    this.rejectionReason,
    required this.submittedAt,
  });

  factory KycSubmission.fromMap(Map<String, dynamic> map) => KycSubmission(
        profileId: map['profile_id'] as String,
        fullName: map['full_name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        documentType: map['document_type'] as String?,
        idNumber: map['id_number'] as String? ?? '',
        idDocumentUrl: map['id_document_url'] as String? ?? '',
        status: map['status'] as String,
        rejectionReason: map['rejection_reason'] as String?,
        submittedAt: DateTime.parse(map['submitted_at'] as String),
      );

  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
}
