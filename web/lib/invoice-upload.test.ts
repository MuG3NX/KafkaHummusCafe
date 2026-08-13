import { describe, expect, it, vi } from "vitest";
import { runInvoiceUploadFlow, runPostUploadExtractionFlow } from "./invoice-upload";

describe("invoice upload and extraction phases", () => {
  it("keeps a record recoverable when Storage reports an ambiguous failure", async () => {
    const reloadPersisted = vi.fn(async () => ({ status: "uploading" as const }));
    const outcome = await runInvoiceUploadFlow({
      createRecord: vi.fn(async () => undefined),
      uploadObject: vi.fn(async () => { throw new Error("network failure"); }),
      markUploaded: vi.fn(async () => undefined),
      reloadPersisted,
      requestExtraction: vi.fn(async () => ({ ok: true }))
    });
    expect(outcome.state.status).toBe("uploading");
    expect(outcome.message).toContain("remains recoverable");
    expect(reloadPersisted).toHaveBeenCalledOnce();
  });

  it("shows persisted needs_review after extraction returns 503", async () => {
    const events: string[] = [];
    const reloadPersisted = vi.fn()
      .mockImplementation(async () => { events.push("reload"); return { status: "needs_review" as const }; });
    const outcome = await runPostUploadExtractionFlow({
      markUploaded: vi.fn(async () => { events.push("mark"); }),
      reloadPersisted,
      requestExtraction: vi.fn(async () => { events.push("extract"); return { ok: false }; })
    });
    expect(outcome.state.status).toBe("needs_review");
    expect(outcome.message).toContain("Original saved");
    expect(events).toEqual(["mark", "reload", "extract"]);
    expect(reloadPersisted).toHaveBeenCalledOnce();
  });

  it("shows persisted needs_review after extraction throws", async () => {
    const reloadPersisted = vi.fn()
      .mockResolvedValueOnce({ status: "needs_review" as const });
    const outcome = await runPostUploadExtractionFlow({
      markUploaded: vi.fn(async () => undefined),
      reloadPersisted,
      requestExtraction: vi.fn(async () => { throw new Error("request failed"); })
    });
    expect(outcome.state.status).toBe("needs_review");
    expect(outcome.message).toContain("Automatic extraction is unavailable");
    expect(reloadPersisted).toHaveBeenCalledOnce();
  });

  it("reloads the latest persisted draft after successful extraction", async () => {
    const reloadPersisted = vi.fn()
      .mockResolvedValueOnce({ status: "needs_review" as const })
      .mockResolvedValueOnce({ status: "needs_review" as const });
    const outcome = await runPostUploadExtractionFlow({
      markUploaded: vi.fn(async () => undefined),
      reloadPersisted,
      requestExtraction: vi.fn(async () => ({ ok: true }))
    });
    expect(outcome.state.status).toBe("needs_review");
    expect(reloadPersisted).toHaveBeenCalledTimes(2);
  });
});
