export type InvoiceExtractionDraft = {
  supplierName: string;
  invoiceNumber: string;
  issueDate: string;
  dueDate: string;
  currency: "CZK" | "EUR";
  netMinor: string;
  vatMinor: string;
  grossMinor: string;
  confidence: Record<string, number>;
  validationErrors: string[];
};

/** Shared empty shape only; extraction adapters are server-only. */
export function emptyInvoiceExtractionDraft(): InvoiceExtractionDraft {
  return {
    supplierName: "",
    invoiceNumber: "",
    issueDate: "",
    dueDate: "",
    currency: "CZK",
    netMinor: "",
    vatMinor: "",
    grossMinor: "",
    confidence: {},
    validationErrors: []
  };
}
