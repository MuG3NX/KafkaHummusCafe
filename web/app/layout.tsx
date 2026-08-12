import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "KAFKA Platform",
  description: "KAFKA restaurant operations platform",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "KAFKA", statusBarStyle: "black-translucent" },
  icons: { apple: "/icon.svg" }
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#171714"
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
