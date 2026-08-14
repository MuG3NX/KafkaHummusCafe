create or replace function public.get_approved_invoice_costs(
  p_location_id uuid,
  p_month date
)
returns table (
  invoice_id uuid,
  storage_path text,
  original_filename text,
  approved_draft_version integer,
  supplier_name text,
  invoice_number text,
  issue_date date,
  due_date date,
  currency text,
  net_minor text,
  vat_minor text,
  gross_minor text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  month_start date;
  month_end date;
begin
  if p_location_id is null or p_month is null then
    raise exception 'A location and month are required';
  end if;
  if not public.is_location_owner(p_location_id) then
    raise exception 'Only the owner can view approved invoice costs';
  end if;

  month_start := date_trunc('month', p_month)::date;
  month_end := (month_start + interval '1 month')::date;

  return query
  select
    invoice.id,
    invoice.storage_path,
    invoice.original_filename,
    invoice.approved_draft_version,
    approved.supplier_name,
    approved.invoice_number,
    approved.issue_date,
    approved.due_date,
    approved.currency,
    approved.net_minor::text,
    approved.vat_minor::text,
    approved.gross_minor::text
  from public.invoice_records invoice
  join public.invoice_extraction_drafts approved
    on approved.invoice_id = invoice.id
   and approved.version = invoice.approved_draft_version
  where invoice.location_id = p_location_id
    and invoice.status = 'approved'
    and approved.issue_date >= month_start
    and approved.issue_date < month_end
  order by approved.issue_date desc, approved.supplier_name, invoice.id;
end;
$$;

revoke execute on function public.get_approved_invoice_costs(uuid, date) from public, anon, authenticated;
grant execute on function public.get_approved_invoice_costs(uuid, date) to authenticated;
