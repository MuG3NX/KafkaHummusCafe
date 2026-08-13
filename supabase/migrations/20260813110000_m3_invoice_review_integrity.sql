alter table public.invoice_records
  drop constraint invoice_records_status_check;

alter table public.invoice_records
  add constraint invoice_records_status_check
  check (status in ('uploading', 'needs_review', 'approved', 'rejected', 'abandoned'));

alter table public.invoice_records
  add constraint invoice_records_approval_pointer_check
  check (
    (status = 'approved' and approved_draft_version is not null)
    or (status <> 'approved' and approved_draft_version is null)
  );

alter table public.invoice_audit_events
  drop constraint invoice_audit_events_event_type_check;

alter table public.invoice_audit_events
  add constraint invoice_audit_events_event_type_check
  check (event_type in ('created', 'uploaded', 'draft_saved', 'approved', 'rejected', 'abandoned', 'corrected'));

create or replace function public.abandon_invoice_upload(p_invoice_id uuid, p_reason text)
returns setof public.invoice_records
language plpgsql
security definer
set search_path = public
as $$
declare
  invoice public.invoice_records;
  updated_invoice public.invoice_records;
begin
  select * into invoice from public.invoice_records where id = p_invoice_id for update;
  if invoice.id is null or not public.can_access_location(invoice.location_id)
     or (invoice.uploaded_by <> auth.uid() and not public.is_location_owner(invoice.location_id)) then
    raise exception 'Not authorized to abandon this invoice upload';
  end if;
  if invoice.status <> 'uploading' then raise exception 'Invoice is not awaiting upload'; end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then raise exception 'A failure reason is required'; end if;

  update public.invoice_records
  set status = 'abandoned', version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, updated_invoice.version, 'abandoned', auth.uid(), trim(p_reason),
    jsonb_build_object('status', updated_invoice.status, 'upload_failed', true));
  return next updated_invoice;
end;
$$;

drop function public.approve_invoice(uuid, text);

create or replace function public.approve_invoice(
  p_invoice_id uuid,
  p_draft_version integer,
  p_invoice_version integer,
  p_reason text default null
)
returns setof public.invoice_records
language plpgsql
security definer
set search_path = public
as $$
declare
  invoice public.invoice_records;
  reviewed_draft public.invoice_extraction_drafts;
  latest_version integer;
  validation_errors text[];
  updated_invoice public.invoice_records;
begin
  select * into invoice from public.invoice_records where id = p_invoice_id for update;
  if invoice.id is null or not public.is_location_owner(invoice.location_id) then
    raise exception 'Only the owner can approve invoices';
  end if;
  if invoice.status <> 'needs_review' then raise exception 'Invoice is not ready for approval'; end if;
  if p_invoice_version is null or invoice.version <> p_invoice_version then
    raise exception 'Invoice changed since it was loaded; reload before approval';
  end if;
  if p_draft_version is null then raise exception 'A reviewed draft version is required'; end if;

  select * into reviewed_draft
  from public.invoice_extraction_drafts
  where invoice_id = invoice.id and version = p_draft_version;
  if reviewed_draft.id is null then raise exception 'The reviewed draft does not belong to this invoice'; end if;
  select max(version) into latest_version from public.invoice_extraction_drafts where invoice_id = invoice.id;
  if latest_version <> p_draft_version then
    raise exception 'The reviewed draft is stale; reload before approval';
  end if;
  validation_errors := public.invoice_draft_validation_errors(
    reviewed_draft.supplier_name, reviewed_draft.invoice_number, reviewed_draft.issue_date, reviewed_draft.due_date,
    reviewed_draft.currency, reviewed_draft.net_minor, reviewed_draft.vat_minor, reviewed_draft.gross_minor
  );
  if cardinality(validation_errors) > 0 then
    raise exception 'Invoice draft is not valid: %', array_to_string(validation_errors, ', ');
  end if;

  update public.invoice_records
  set status = 'approved', approved_draft_version = p_draft_version,
      version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, updated_invoice.version, 'approved', auth.uid(), nullif(trim(p_reason), ''),
    jsonb_build_object('draft_version', p_draft_version, 'approved_draft_version', p_draft_version));
  return next updated_invoice;
end;
$$;

revoke execute on function public.approve_invoice(uuid, integer, integer, text) from public, anon, authenticated;
grant execute on function public.approve_invoice(uuid, integer, integer, text) to authenticated;
