-- Adds an explicit document_type to KYC submissions instead of relying on
-- a technician reading a hint and typing the right kind of ID number.
-- Deliberately excludes Aadhaar as a valid value -- collecting Aadhaar
-- (even just the number) needs UIDAI authorisation this app doesn't have,
-- and masking the number was never enough anyway since the uploaded
-- document photo itself would still show it. See profile_repository.dart
-- (upsertTechnicianKyc) and technician_profile_setup_screen.dart, which
-- now present a fixed choice of PAN / Voter ID / Driving Licence.
alter table technician_kyc add column if not exists document_type text;

alter table technician_kyc drop constraint if exists technician_kyc_document_type_check;
alter table technician_kyc add constraint technician_kyc_document_type_check
  check (document_type is null or document_type in ('PAN', 'Voter ID', 'Driving Licence'));

-- Recreated (not just replaced) because CREATE OR REPLACE FUNCTION can't
-- change a returns-table's column list.
drop function if exists public.admin_list_kyc(text);
create function public.admin_list_kyc(p_status text default null)
returns table (
  profile_id uuid,
  full_name text,
  phone text,
  document_type text,
  id_number text,
  id_document_url text,
  status text,
  rejection_reason text,
  submitted_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  return query
    select k.profile_id, p.full_name, p.phone, k.document_type, k.id_number, k.id_document_url,
           k.status, k.rejection_reason, k.submitted_at
    from technician_kyc k
    join profiles p on p.id = k.profile_id
    where p_status is null or k.status = p_status
    order by k.submitted_at;
end;
$$;

grant execute on function public.admin_list_kyc(text) to authenticated;
