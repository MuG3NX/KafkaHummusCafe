import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";
import { noProviderInvoiceAdapter } from "../../../../../lib/server/invoice-extraction";

export async function POST(_request: Request, { params }: { params: Promise<{ invoiceId: string }> }) {
  const invoiceId = (await params).invoiceId;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const secretKey = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !publishableKey) return NextResponse.json({ error: "Supabase is not configured" }, { status: 500 });

  const cookieStore = await cookies();
  const userClient = createServerClient(url, publishableKey, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: () => undefined
    }
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return NextResponse.json({ error: "Authentication required" }, { status: 401 });

  const { data: invoice, error: invoiceError } = await userClient
    .from("invoice_records")
    .select("id, storage_path, original_mime_type")
    .eq("id", invoiceId)
    .maybeSingle();
  if (invoiceError || !invoice) return NextResponse.json({ error: "Invoice not found" }, { status: 404 });
  if (!secretKey) return NextResponse.json({ available: false, message: "No OCR adapter secret is configured" }, { status: 503 });

  const draft = await noProviderInvoiceAdapter.extract({
    invoiceId: invoice.id,
    bucket: "invoice-originals",
    storagePath: invoice.storage_path,
    mimeType: invoice.original_mime_type
  });
  const adminClient = createClient(url, secretKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { error: saveError } = await adminClient.rpc("save_invoice_adapter_draft", {
    p_invoice_id: invoice.id,
    p_actor_id: userData.user.id,
    p_provider_key: draft.providerKey,
    p_supplier_name: draft.supplierName,
    p_invoice_number: draft.invoiceNumber,
    p_issue_date: draft.issueDate,
    p_due_date: draft.dueDate,
    p_currency: draft.currency,
    p_net_minor: draft.netMinor,
    p_vat_minor: draft.vatMinor,
    p_gross_minor: draft.grossMinor,
    p_confidence: draft.confidence,
    p_validation_errors: draft.validationErrors
  });
  if (saveError) return NextResponse.json({ error: saveError.message }, { status: 500 });
  return NextResponse.json({ available: true, providerKey: draft.providerKey });
}
