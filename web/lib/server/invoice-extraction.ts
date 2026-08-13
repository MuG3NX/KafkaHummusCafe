import "server-only";

export type ServerInvoiceExtractionInput = {
  invoiceId: string;
  bucket: string;
  storagePath: string;
  mimeType: string;
};

export type ServerInvoiceExtractionDraft = {
  providerKey: string;
  supplierName: string | null;
  invoiceNumber: string | null;
  issueDate: string | null;
  dueDate: string | null;
  currency: "CZK" | "EUR";
  netMinor: string | null;
  vatMinor: string | null;
  grossMinor: string | null;
  confidence: Record<string, number>;
  validationErrors: string[];
};

/** Server-only adapter boundary. It will read the private object once a provider exists. */
export const noProviderInvoiceAdapter = {
  key: "none",
  async extract(input: ServerInvoiceExtractionInput): Promise<ServerInvoiceExtractionDraft> {
    void input;
    return {
      providerKey: "none",
      supplierName: null,
      invoiceNumber: null,
      issueDate: null,
      dueDate: null,
      currency: "CZK",
      netMinor: null,
      vatMinor: null,
      grossMinor: null,
      confidence: {},
      validationErrors: ["No OCR provider configured"]
    };
  }
};
