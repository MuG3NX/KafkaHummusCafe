alter table public.invoice_records
  add column approved_draft_version integer;

alter table public.invoice_records
  add constraint invoice_records_approved_draft_fk
  foreign key (id, approved_draft_version)
  references public.invoice_extraction_drafts (invoice_id, version);

revoke update, delete on storage.objects from anon, authenticated;

create or replace function public.invoice_storage_metadata_size(p_metadata jsonb)
returns bigint
language plpgsql
immutable
as $$
begin
  return (p_metadata ->> 'size')::bigint;
exception when invalid_text_representation then
  return null;
end;
$$;

create or replace function public.invoice_draft_validation_errors(
  p_supplier_name text,
  p_invoice_number text,
  p_issue_date date,
  p_due_date date,
  p_currency text,
  p_net_minor bigint,
  p_vat_minor bigint,
  p_gross_minor bigint
)
returns text[]
language plpgsql
immutable
as $$
declare
  errors text[] := '{}'::text[];
begin
  if nullif(trim(coalesce(p_supplier_name, '')), '') is null then
    errors := array_append(errors, 'supplier_name_required');
  end if;
  if nullif(trim(coalesce(p_invoice_number, '')), '') is null then
    errors := array_append(errors, 'invoice_number_required');
  end if;
  if p_issue_date is null then
    errors := array_append(errors, 'issue_date_required');
  end if;
  if p_due_date is not null and p_issue_date is not null and p_due_date < p_issue_date then
    errors := array_append(errors, 'due_date_before_issue_date');
  end if;
  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then
    errors := array_append(errors, 'currency_invalid');
  end if;
  if p_net_minor is null then errors := array_append(errors, 'net_required'); end if;
  if p_vat_minor is null then errors := array_append(errors, 'vat_required'); end if;
  if p_gross_minor is null then errors := array_append(errors, 'gross_required'); end if;
  if p_net_minor is not null and p_net_minor < 0 then errors := array_append(errors, 'net_negative'); end if;
  if p_vat_minor is not null and p_vat_minor < 0 then errors := array_append(errors, 'vat_negative'); end if;
  if p_gross_minor is not null and p_gross_minor < 0 then errors := array_append(errors, 'gross_negative'); end if;
  if p_net_minor is not null and p_vat_minor is not null and p_gross_minor is not null
     and p_gross_minor <> p_net_minor + p_vat_minor then
    errors := array_append(errors, 'gross_not_net_plus_vat');
  end if;
  return errors;
end;
$$;

create or replace function public.mark_invoice_uploaded(p_invoice_id uuid)
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
    raise exception 'Not authorized to complete this invoice upload';
  end if;
  if invoice.status <> 'uploading' then
    raise exception 'Invoice upload is already complete';
  end if;
  if not exists (
    select 1
    from storage.objects object
    where object.bucket_id = 'invoice-originals'
      and object.name = invoice.storage_path
      and object.metadata ->> 'mimetype' = invoice.original_mime_type
      and public.invoice_storage_metadata_size(object.metadata) = invoice.original_size_bytes
  ) then
    raise exception 'The exact invoice original has not been uploaded';
  end if;

  update public.invoice_records
  set status = 'needs_review', version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, snapshot)
  values (invoice.id, updated_invoice.version, 'uploaded', auth.uid(), jsonb_build_object('status', updated_invoice.status));
  return next updated_invoice;
end;
$$;

create or replace function public.save_invoice_manual_draft(
  p_invoice_id uuid,
  p_supplier_name text,
  p_invoice_number text,
  p_issue_date date,
  p_due_date date,
  p_currency text,
  p_net_minor bigint,
  p_vat_minor bigint,
  p_gross_minor bigint,
  p_confidence jsonb,
  p_validation_errors jsonb,
  p_reason text default null
)
returns setof public.invoice_records
language plpgsql
security definer
set search_path = public
as $$
declare
  invoice public.invoice_records;
  next_version integer;
  updated_invoice public.invoice_records;
  event_type text := 'draft_saved';
begin
  select * into invoice from public.invoice_records where id = p_invoice_id for update;
  if invoice.id is null or not public.is_location_owner(invoice.location_id) then
    raise exception 'Only the owner can edit invoice fields';
  end if;
  if invoice.status = 'approved' then
    if length(trim(coalesce(p_reason, ''))) = 0 then
      raise exception 'Approved invoice corrections require a reason';
    end if;
    event_type := 'corrected';
  elsif invoice.status not in ('needs_review', 'rejected') then
    raise exception 'Invoice is not ready for review';
  end if;
  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then raise exception 'Invalid invoice currency'; end if;
  if p_net_minor is not null and p_net_minor < 0 then raise exception 'Net amount cannot be negative'; end if;
  if p_vat_minor is not null and p_vat_minor < 0 then raise exception 'VAT amount cannot be negative'; end if;
  if p_gross_minor is not null and p_gross_minor < 0 then raise exception 'Gross amount cannot be negative'; end if;

  next_version := invoice.version + 1;
  insert into public.invoice_extraction_drafts (
    invoice_id, version, source, provider_key, supplier_name, invoice_number,
    issue_date, due_date, currency, net_minor, vat_minor, gross_minor,
    confidence, validation_errors, created_by
  ) values (
    invoice.id, next_version, 'manual', null,
    nullif(trim(p_supplier_name), ''), nullif(trim(p_invoice_number), ''),
    p_issue_date, p_due_date, p_currency, p_net_minor, p_vat_minor, p_gross_minor,
    coalesce(p_confidence, '{}'::jsonb), coalesce(p_validation_errors, '[]'::jsonb), auth.uid()
  );
  update public.invoice_records
  set status = 'needs_review', approved_draft_version = null, version = next_version, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, next_version, event_type, auth.uid(), nullif(trim(p_reason), ''),
    jsonb_build_object('status', updated_invoice.status, 'source', 'manual'));
  return next updated_invoice;
end;
$$;

create or replace function public.save_invoice_adapter_draft(
  p_invoice_id uuid,
  p_actor_id uuid,
  p_provider_key text,
  p_supplier_name text,
  p_invoice_number text,
  p_issue_date date,
  p_due_date date,
  p_currency text,
  p_net_minor bigint,
  p_vat_minor bigint,
  p_gross_minor bigint,
  p_confidence jsonb,
  p_validation_errors jsonb
)
returns setof public.invoice_records
language plpgsql
security definer
set search_path = public
as $$
declare
  invoice public.invoice_records;
  next_version integer;
  updated_invoice public.invoice_records;
begin
  if p_actor_id is null or nullif(trim(coalesce(p_provider_key, '')), '') is null then
    raise exception 'Trusted adapter identity is required';
  end if;
  select * into invoice from public.invoice_records where id = p_invoice_id for update;
  if invoice.id is null or invoice.status not in ('needs_review', 'rejected') then
    raise exception 'Invoice is not ready for adapter extraction';
  end if;
  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then raise exception 'Invalid invoice currency'; end if;
  if p_net_minor is not null and p_net_minor < 0 then raise exception 'Net amount cannot be negative'; end if;
  if p_vat_minor is not null and p_vat_minor < 0 then raise exception 'VAT amount cannot be negative'; end if;
  if p_gross_minor is not null and p_gross_minor < 0 then raise exception 'Gross amount cannot be negative'; end if;

  next_version := invoice.version + 1;
  insert into public.invoice_extraction_drafts (
    invoice_id, version, source, provider_key, supplier_name, invoice_number,
    issue_date, due_date, currency, net_minor, vat_minor, gross_minor,
    confidence, validation_errors, created_by
  ) values (
    invoice.id, next_version, 'adapter', trim(p_provider_key),
    nullif(trim(p_supplier_name), ''), nullif(trim(p_invoice_number), ''),
    p_issue_date, p_due_date, p_currency, p_net_minor, p_vat_minor, p_gross_minor,
    coalesce(p_confidence, '{}'::jsonb), coalesce(p_validation_errors, '[]'::jsonb), p_actor_id
  );
  update public.invoice_records
  set status = 'needs_review', approved_draft_version = null, version = next_version, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, snapshot)
  values (invoice.id, next_version, 'draft_saved', p_actor_id,
    jsonb_build_object('status', updated_invoice.status, 'source', 'adapter', 'provider_key', trim(p_provider_key)));
  return next updated_invoice;
end;
$$;

create or replace function public.approve_invoice(
  p_invoice_id uuid,
  p_reason text default null
)
returns setof public.invoice_records
language plpgsql
security definer
set search_path = public
as $$
declare
  invoice public.invoice_records;
  latest_draft public.invoice_extraction_drafts;
  validation_errors text[];
  updated_invoice public.invoice_records;
begin
  select * into invoice from public.invoice_records where id = p_invoice_id for update;
  if invoice.id is null or not public.is_location_owner(invoice.location_id) then
    raise exception 'Only the owner can approve invoices';
  end if;
  if invoice.status <> 'needs_review' then raise exception 'Invoice is not ready for approval'; end if;
  select * into latest_draft from public.invoice_extraction_drafts where invoice_id = invoice.id order by version desc limit 1;
  if latest_draft.id is null then raise exception 'Invoice needs an extraction draft before approval'; end if;
  validation_errors := public.invoice_draft_validation_errors(
    latest_draft.supplier_name, latest_draft.invoice_number, latest_draft.issue_date, latest_draft.due_date,
    latest_draft.currency, latest_draft.net_minor, latest_draft.vat_minor, latest_draft.gross_minor
  );
  if cardinality(validation_errors) > 0 then
    raise exception 'Invoice draft is not valid: %', array_to_string(validation_errors, ', ');
  end if;

  update public.invoice_records
  set status = 'approved', approved_draft_version = latest_draft.version,
      version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, updated_invoice.version, 'approved', auth.uid(), nullif(trim(p_reason), ''),
    jsonb_build_object('draft_version', latest_draft.version, 'approved_draft_version', latest_draft.version));
  return next updated_invoice;
end;
$$;

create or replace function public.reject_invoice(
  p_invoice_id uuid,
  p_reason text
)
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
  if invoice.id is null or not public.is_location_owner(invoice.location_id) then
    raise exception 'Only the owner can reject invoices';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then raise exception 'A rejection reason is required'; end if;
  if invoice.status <> 'needs_review' then raise exception 'Invoice is not ready for rejection'; end if;
  update public.invoice_records
  set status = 'rejected', approved_draft_version = null, version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, updated_invoice.version, 'rejected', auth.uid(), trim(p_reason), jsonb_build_object('status', updated_invoice.status));
  return next updated_invoice;
end;
$$;

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
  set status = 'rejected', version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, updated_invoice.version, 'rejected', auth.uid(), trim(p_reason),
    jsonb_build_object('status', updated_invoice.status, 'upload_failed', true));
  return next updated_invoice;
end;
$$;

drop policy if exists invoice_originals_read on storage.objects;
drop policy if exists invoice_originals_insert on storage.objects;

create policy invoice_originals_read on storage.objects for select to authenticated using (
  bucket_id = 'invoice-originals'
  and exists (
    select 1 from public.invoice_records invoice
    where invoice.storage_path = name
      and public.can_access_location(invoice.location_id)
  )
);

create policy invoice_originals_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'invoice-originals'
  and exists (
    select 1 from public.invoice_records invoice
    where invoice.storage_path = name
      and invoice.status = 'uploading'
      and invoice.uploaded_by = auth.uid()
      and invoice.original_mime_type = metadata ->> 'mimetype'
      and invoice.original_size_bytes = public.invoice_storage_metadata_size(metadata)
  )
);

revoke execute on function public.invoice_storage_metadata_size(jsonb) from public, anon, authenticated;
revoke execute on function public.invoice_draft_validation_errors(text, text, date, date, text, bigint, bigint, bigint) from public, anon, authenticated;
revoke execute on function public.mark_invoice_uploaded(uuid) from public, anon, authenticated;
revoke execute on function public.save_invoice_extraction_draft(uuid, text, text, text, text, date, date, text, bigint, bigint, bigint, jsonb, jsonb, text) from public, anon, authenticated;
revoke execute on function public.save_invoice_manual_draft(uuid, text, text, date, date, text, bigint, bigint, bigint, jsonb, jsonb, text) from public, anon, authenticated;
revoke execute on function public.save_invoice_adapter_draft(uuid, uuid, text, text, text, date, date, text, bigint, bigint, bigint, jsonb, jsonb) from public, anon, authenticated;
revoke execute on function public.approve_invoice(uuid, text) from public, anon, authenticated;
revoke execute on function public.reject_invoice(uuid, text) from public, anon, authenticated;
revoke execute on function public.abandon_invoice_upload(uuid, text) from public, anon, authenticated;

grant execute on function public.mark_invoice_uploaded(uuid) to authenticated;
grant execute on function public.invoice_storage_metadata_size(jsonb) to authenticated;
grant execute on function public.save_invoice_manual_draft(uuid, text, text, date, date, text, bigint, bigint, bigint, jsonb, jsonb, text) to authenticated;
grant execute on function public.approve_invoice(uuid, text) to authenticated;
grant execute on function public.reject_invoice(uuid, text) to authenticated;
grant execute on function public.abandon_invoice_upload(uuid, text) to authenticated;
grant execute on function public.save_invoice_adapter_draft(uuid, uuid, text, text, text, date, date, text, bigint, bigint, bigint, jsonb, jsonb) to service_role;
