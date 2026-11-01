import type { Metadata, Viewport } from "next";
import { ThemeProvider } from "@/context/ThemeContext";
import { AdminAuthProvider } from "@/context/AdminAuthContext";
import "../globals.css";

/**
 * Root layout for the admin section.
 *
 * The project has no `app/layout.tsx`: `(shop)/layout.tsx` is the storefront's
 * root layout, so admin needs its own root layout in its own route group. The
 * route group name is stripped from the URL, so pages here still resolve to
 * /admin/*, and `/` remains defined inside (shop) as multiple root layouts
 * require.
 *
 * Deliberately NOT included here: AppShell, BottomNavigation, CartProvider and
 * WishlistProvider. The admin panel is a full-width dashboard, not the 480px
 * mobile storefront shell, and it has no cart. The two trees share no chrome, so
 * the customer app reaches this one only through lib/admin/entry.ts.
 */
export const metadata: Metadata = {
  title: "Apple Expert — Admin",
  description: "Apple Expert administration.",
  // Never index the admin surface.
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#08110d" },
  ],
  width: "device-width",
  initialScale: 1,
};

export default function AdminRootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased selection:bg-primary/30">
        <ThemeProvider>
          <AdminAuthProvider>{children}</AdminAuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
