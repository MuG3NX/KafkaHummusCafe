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

export type InvoiceExtractionInput = { fileName: string; mimeType: string };

export interface InvoiceExtractionAdapter {
  readonly key: string;
  extract(input: InvoiceExtractionInput): Promise<InvoiceExtractionDraft>;
}

/** Foundation adapter: preserves the provider boundary without inventing OCR. */
export const noProviderInvoiceAdapter: InvoiceExtractionAdapter = {
  key: "none",
  async extract(input) {
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
      validationErrors: [`No OCR provider configured for ${input.fileName}`]
    };
  }
};
