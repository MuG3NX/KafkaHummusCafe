-- Supabase Storage supplies the authoritative object size in storage.objects
-- metadata after the object is written. Do not require that generated field
-- during INSERT RLS evaluation; mark_invoice_uploaded verifies the exact
-- MIME type and size before making the invoice reviewable.
drop policy if exists invoice_originals_insert on storage.objects;

create policy invoice_originals_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'invoice-originals'
  and exists (
    select 1
    from public.invoice_records invoice
    where invoice.storage_path = name
      and invoice.status = 'uploading'
      and invoice.uploaded_by = auth.uid()
      and invoice.original_mime_type = metadata ->> 'mimetype'
  )
);
