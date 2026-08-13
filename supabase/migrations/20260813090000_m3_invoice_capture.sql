alter table public.locations
  add constraint locations_id_restaurant_key unique (id, restaurant_id);

create table public.invoice_records (
  id uuid primary key,
  restaurant_id uuid not null references public.restaurants(id),
  location_id uuid not null references public.locations(id),
  uploaded_by uuid not null references auth.users(id),
  storage_path text not null unique,
  original_filename text not null check (length(trim(original_filename)) > 0),
  original_mime_type text not null check (original_mime_type in ('application/pdf', 'image/jpeg', 'image/png', 'image/webp')),
  original_size_bytes bigint not null check (original_size_bytes > 0 and original_size_bytes <= 25000000),
  status text not null default 'uploading' check (status in ('uploading', 'needs_review', 'approved', 'rejected')),
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint invoice_records_location_tenant_fk
    foreign key (location_id, restaurant_id)
    references public.locations (id, restaurant_id),
  constraint invoice_records_storage_path_check
    check (storage_path like location_id::text || '/' || id::text || '/%')
);

create table public.invoice_extraction_drafts (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoice_records(id),
  version integer not null check (version > 0),
  source text not null check (source in ('manual', 'adapter')),
  provider_key text,
  supplier_name text,
  invoice_number text,
  issue_date date,
  due_date date,
  currency text not null default 'CZK' check (currency ~ '^[A-Z]{3}$'),
  net_minor bigint check (net_minor is null or net_minor >= 0),
  vat_minor bigint check (vat_minor is null or vat_minor >= 0),
  gross_minor bigint check (gross_minor is null or gross_minor >= 0),
  confidence jsonb not null default '{}'::jsonb,
  validation_errors jsonb not null default '[]'::jsonb,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (invoice_id, version)
);

create table public.invoice_audit_events (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoice_records(id),
  version integer not null check (version > 0),
  event_type text not null check (event_type in ('created', 'uploaded', 'draft_saved', 'approved', 'rejected', 'corrected')),
  changed_by uuid not null references auth.users(id),
  reason text,
  snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (invoice_id, version)
);

create index invoice_records_location_created_idx
  on public.invoice_records (location_id, created_at desc);
create index invoice_drafts_invoice_version_idx
  on public.invoice_extraction_drafts (invoice_id, version desc);
create index invoice_audit_invoice_created_idx
  on public.invoice_audit_events (invoice_id, created_at desc);

insert into storage.buckets (id, name, public)
values ('invoice-originals', 'invoice-originals', false)
on conflict (id) do update set public = false;

create or replace function public.invoice_storage_location_id(object_name text)
returns uuid
language plpgsql
immutable
as $$
begin
  return split_part(object_name, '/', 1)::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

create or replace function public.create_invoice_record(
  p_invoice_id uuid,
  p_location_id uuid,
  p_storage_path text,
  p_original_filename text,
  p_original_mime_type text,
  p_original_size_bytes bigint
)
returns setof public.invoice_records
language plpgsql
security definer
set search_path = public
as $$
declare
  location_row public.locations;
  new_invoice public.invoice_records;
begin
  select * into location_row from public.locations where id = p_location_id;
  if location_row.id is null or not public.can_access_location(p_location_id) then
    raise exception 'Not authorized for this invoice location';
  end if;
  if p_storage_path <> p_location_id::text || '/' || p_invoice_id::text || '/' || split_part(p_storage_path, '/', 3)
     or split_part(p_storage_path, '/', 1)::uuid <> p_location_id
     or split_part(p_storage_path, '/', 2)::uuid <> p_invoice_id then
    raise exception 'Invoice storage path is invalid';
  end if;
  if p_original_mime_type not in ('application/pdf', 'image/jpeg', 'image/png', 'image/webp') then
    raise exception 'Unsupported invoice file type';
  end if;
  if p_original_size_bytes <= 0 or p_original_size_bytes > 25000000 then
    raise exception 'Invoice file size is invalid';
  end if;

  insert into public.invoice_records (
    id, restaurant_id, location_id, uploaded_by, storage_path,
    original_filename, original_mime_type, original_size_bytes
  ) values (
    p_invoice_id, location_row.restaurant_id, p_location_id, auth.uid(), p_storage_path,
    trim(p_original_filename), p_original_mime_type, p_original_size_bytes
  ) returning * into new_invoice;

  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, snapshot)
  values (new_invoice.id, new_invoice.version, 'created', auth.uid(), jsonb_build_object('status', new_invoice.status));
  return next new_invoice;
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

  update public.invoice_records
  set status = 'needs_review', version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, snapshot)
  values (invoice.id, updated_invoice.version, 'uploaded', auth.uid(), jsonb_build_object('status', updated_invoice.status));
  return next updated_invoice;
end;
$$;

create or replace function public.save_invoice_extraction_draft(
  p_invoice_id uuid,
  p_source text,
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
  if invoice.id is null or not public.can_access_location(invoice.location_id) then
    raise exception 'Not authorized to edit this invoice draft';
  end if;
  if invoice.status = 'approved' then
    if not public.is_location_owner(invoice.location_id) or length(trim(coalesce(p_reason, ''))) = 0 then
      raise exception 'Approved invoice corrections require owner authorization and a reason';
    end if;
    event_type := 'corrected';
  elsif invoice.status not in ('needs_review', 'rejected') then
    raise exception 'Invoice is not ready for review';
  end if;
  if p_source not in ('manual', 'adapter') then raise exception 'Invalid extraction source'; end if;
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
    invoice.id, next_version, p_source, nullif(trim(p_provider_key), ''),
    nullif(trim(p_supplier_name), ''), nullif(trim(p_invoice_number), ''),
    p_issue_date, p_due_date, p_currency, p_net_minor, p_vat_minor, p_gross_minor,
    coalesce(p_confidence, '{}'::jsonb), coalesce(p_validation_errors, '[]'::jsonb), auth.uid()
  );
  update public.invoice_records
  set status = 'needs_review', version = next_version, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, next_version, event_type, auth.uid(), nullif(trim(p_reason), ''), jsonb_build_object('status', updated_invoice.status, 'source', p_source));
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
  updated_invoice public.invoice_records;
begin
  select * into invoice from public.invoice_records where id = p_invoice_id for update;
  if invoice.id is null or not public.is_location_owner(invoice.location_id) then
    raise exception 'Only the owner can approve invoices';
  end if;
  if invoice.status <> 'needs_review' then raise exception 'Invoice is not ready for approval'; end if;
  select * into latest_draft from public.invoice_extraction_drafts where invoice_id = invoice.id order by version desc limit 1;
  if latest_draft.id is null then raise exception 'Invoice needs an extraction draft before approval'; end if;

  update public.invoice_records
  set status = 'approved', version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, updated_invoice.version, 'approved', auth.uid(), nullif(trim(p_reason), ''), jsonb_build_object('draft_version', latest_draft.version));
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
  set status = 'rejected', version = invoice.version + 1, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, reason, snapshot)
  values (invoice.id, updated_invoice.version, 'rejected', auth.uid(), trim(p_reason), jsonb_build_object('status', updated_invoice.status));
  return next updated_invoice;
end;
$$;

alter table public.invoice_records enable row level security;
alter table public.invoice_extraction_drafts enable row level security;
alter table public.invoice_audit_events enable row level security;

create policy invoice_records_read on public.invoice_records for select using (
  public.can_access_location(location_id)
);
create policy invoice_drafts_read on public.invoice_extraction_drafts for select using (
  exists (select 1 from public.invoice_records i where i.id = invoice_id and public.can_access_location(i.location_id))
);
create policy invoice_audit_owner_read on public.invoice_audit_events for select using (
  exists (select 1 from public.invoice_records i where i.id = invoice_id and public.is_location_owner(i.location_id))
);

create policy invoice_originals_read on storage.objects for select to authenticated using (
  bucket_id = 'invoice-originals'
  and public.can_access_location(public.invoice_storage_location_id(name))
);
create policy invoice_originals_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'invoice-originals'
  and public.can_access_location(public.invoice_storage_location_id(name))
);

revoke all on public.invoice_records, public.invoice_extraction_drafts, public.invoice_audit_events from anon, authenticated;
grant select on public.invoice_records, public.invoice_extraction_drafts, public.invoice_audit_events to authenticated;
revoke execute on function public.invoice_storage_location_id(text) from public;
revoke execute on function public.create_invoice_record(uuid, uuid, text, text, text, bigint) from public;
revoke execute on function public.mark_invoice_uploaded(uuid) from public;
revoke execute on function public.save_invoice_extraction_draft(uuid, text, text, text, text, date, date, text, bigint, bigint, bigint, jsonb, jsonb, text) from public;
revoke execute on function public.approve_invoice(uuid, text) from public;
revoke execute on function public.reject_invoice(uuid, text) from public;
grant execute on function public.create_invoice_record(uuid, uuid, text, text, text, bigint) to authenticated;
grant execute on function public.mark_invoice_uploaded(uuid) to authenticated;
grant execute on function public.save_invoice_extraction_draft(uuid, text, text, text, text, date, date, text, bigint, bigint, bigint, jsonb, jsonb, text) to authenticated;
grant execute on function public.approve_invoice(uuid, text) to authenticated;
grant execute on function public.reject_invoice(uuid, text) to authenticated;
