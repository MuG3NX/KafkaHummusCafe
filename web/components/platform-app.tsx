"use client";

import { useState } from "react";
import { InvoiceApp } from "./invoice-app";
import { RevenueApp } from "./revenue-app";
import { ShiftsApp } from "./shifts-app";

export function PlatformApp() {
  const [module, setModule] = useState<"revenue" | "shifts" | "invoices">("revenue");
  if (module === "shifts") return <ShiftsApp onOpenRevenue={() => setModule("revenue")} onOpenInvoices={() => setModule("invoices")} />;
  if (module === "invoices") return <InvoiceApp onOpenRevenue={() => setModule("revenue")} onOpenShifts={() => setModule("shifts")} />;
  return <RevenueApp onOpenShifts={() => setModule("shifts")} onOpenInvoices={() => setModule("invoices")} />;
}
