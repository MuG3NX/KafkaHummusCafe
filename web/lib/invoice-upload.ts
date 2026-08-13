export type InvoiceUploadPersistedState = {
  status: "uploading" | "needs_review";
};

export type InvoiceUploadFlowOutcome = {
  state: InvoiceUploadPersistedState;
  extractionAvailable: boolean;
  message: string | null;
};

type ExtractionResponse = { ok: boolean };

export async function runPostUploadExtractionFlow(dependencies: {
  markUploaded: () => Promise<void>;
  reloadPersisted: () => Promise<InvoiceUploadPersistedState>;
  requestExtraction: () => Promise<ExtractionResponse>;
}): Promise<InvoiceUploadFlowOutcome> {
  try {
    await dependencies.markUploaded();
  } catch {
    return {
      state: await dependencies.reloadPersisted().catch(() => ({ status: "uploading" })),
      extractionAvailable: false,
      message: "The original upload could not be confirmed. It remains recoverable as Uploading; use Complete upload or Abandon incomplete upload."
    };
  }

  const completedState = await dependencies.reloadPersisted();
  try {
    const extraction = await dependencies.requestExtraction();
    if (!extraction.ok) {
      return {
        state: completedState,
        extractionAvailable: false,
        message: "Original saved. Automatic extraction is unavailable; the owner can enter the draft manually."
      };
    }
    return { state: await dependencies.reloadPersisted(), extractionAvailable: true, message: null };
  } catch {
    return {
      state: completedState,
      extractionAvailable: false,
      message: "Original saved. Automatic extraction is unavailable; the owner can enter the draft manually."
    };
  }
}

export async function runInvoiceUploadFlow(dependencies: {
  createRecord: () => Promise<void>;
  uploadObject: () => Promise<void>;
  markUploaded: () => Promise<void>;
  reloadPersisted: () => Promise<InvoiceUploadPersistedState>;
  requestExtraction: () => Promise<ExtractionResponse>;
}): Promise<InvoiceUploadFlowOutcome> {
  await dependencies.createRecord();
  try {
    await dependencies.uploadObject();
  } catch {
    return {
      state: await dependencies.reloadPersisted().catch(() => ({ status: "uploading" })),
      extractionAvailable: false,
      message: "The original upload could not be confirmed. It remains recoverable as Uploading; use Complete upload or Abandon incomplete upload."
    };
  }
  return runPostUploadExtractionFlow(dependencies);
}
