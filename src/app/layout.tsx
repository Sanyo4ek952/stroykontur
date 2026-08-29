import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import { serverEnvironment } from "@/server/config/env";

import "./globals.css";
import { ServiceWorkerRegistration } from "./service-worker-registration";

const applicationName = "Строительный объект";

export const metadata: Metadata = {
  applicationName,
  title: {
    default: applicationName,
    template: `%s · ${applicationName}`,
  },
  description: "Рабочее пространство строительного объекта.",
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [
      { url: "/icon.svg", type: "image/svg+xml" },
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: "/icon-192.png",
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: applicationName,
  },
};

export const viewport: Viewport = {
  themeColor: "#0f172a",
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  void serverEnvironment;

  return (
    <html lang="ru">
      <body>
        {children}
        <ServiceWorkerRegistration />
      </body>
    </html>
  );
}
