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

  select * into invoice
  from public.invoice_records
  where id = p_invoice_id
  for update;
  if invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if invoice.uploaded_by <> p_actor_id and not exists (
    select 1
    from public.locations location_row
    join public.restaurant_memberships membership
      on membership.restaurant_id = location_row.restaurant_id
    where location_row.id = invoice.location_id
      and membership.user_id = p_actor_id
      and membership.role = 'owner'
  ) then
    raise exception 'Only the original uploader or location owner can request initial extraction';
  end if;
  if invoice.status <> 'needs_review' then
    raise exception 'Invoice is not ready for initial extraction';
  end if;
  if exists (
    select 1 from public.invoice_extraction_drafts
    where invoice_id = invoice.id
  ) then
    raise exception 'Invoice already has an extraction draft';
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
  set status = 'needs_review', approved_draft_version = null,
      version = next_version, updated_at = clock_timestamp()
  where id = invoice.id
  returning * into updated_invoice;
  insert into public.invoice_audit_events (invoice_id, version, event_type, changed_by, snapshot)
  values (invoice.id, next_version, 'draft_saved', p_actor_id,
    jsonb_build_object('status', updated_invoice.status, 'source', 'adapter', 'provider_key', trim(p_provider_key)));
  return next updated_invoice;
end;
$$;
