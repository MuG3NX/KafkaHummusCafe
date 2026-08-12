"use client";

import { useState } from "react";
import { RevenueApp } from "./revenue-app";
import { ShiftsApp } from "./shifts-app";

export function PlatformApp() {
  const [module, setModule] = useState<"revenue" | "shifts">("revenue");
  if (module === "shifts") return <ShiftsApp onOpenRevenue={() => setModule("revenue")} />;
  return <RevenueApp onOpenShifts={() => setModule("shifts")} />;
}
