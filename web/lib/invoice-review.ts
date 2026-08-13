export type InvoiceReviewStatus = "uploading" | "needs_review" | "approved" | "rejected" | "abandoned";

export function canApproveInvoice(
  status: InvoiceReviewStatus,
  persistedDraftVersion: number | null,
  invoiceVersion: number | null,
  dirty: boolean,
  busy: boolean
): boolean {
  return status === "needs_review" && persistedDraftVersion !== null && invoiceVersion !== null && !dirty && !busy;
}
