"use client";

import { useState } from "react";
import { CostsApp } from "./costs-app";
import { InvoiceApp } from "./invoice-app";
import { RevenueApp } from "./revenue-app";
import { ShiftsApp } from "./shifts-app";

export function PlatformApp() {
  const [module, setModule] = useState<"revenue" | "shifts" | "invoices" | "costs">("revenue");
  if (module === "shifts") return <ShiftsApp onOpenRevenue={() => setModule("revenue")} onOpenInvoices={() => setModule("invoices")} onOpenCosts={() => setModule("costs")} />;
  if (module === "invoices") return <InvoiceApp onOpenRevenue={() => setModule("revenue")} onOpenShifts={() => setModule("shifts")} onOpenCosts={() => setModule("costs")} />;
  if (module === "costs") return <CostsApp onOpenRevenue={() => setModule("revenue")} onOpenInvoices={() => setModule("invoices")} onOpenShifts={() => setModule("shifts")} />;
  return <RevenueApp onOpenShifts={() => setModule("shifts")} onOpenInvoices={() => setModule("invoices")} onOpenCosts={() => setModule("costs")} />;
}
