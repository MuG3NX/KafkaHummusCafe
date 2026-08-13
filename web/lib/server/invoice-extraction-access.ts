export type InitialExtractionAccess = {
  callerId: string;
  uploadedBy: string;
  status: "uploading" | "needs_review" | "approved" | "rejected" | "abandoned";
  isLocationOwner: boolean;
  hasDraft: boolean;
};

export function canRequestInitialExtraction(input: InitialExtractionAccess): boolean {
  const actorAllowed = input.callerId === input.uploadedBy || input.isLocationOwner;
  return actorAllowed && input.status === "needs_review" && !input.hasDraft;
}
