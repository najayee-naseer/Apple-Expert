# Customer authentication

Apple Expert is one app, one database and one catalog. Retail customers,
wholesale customers and administrators all live in the same Supabase project;
what differs is what PostgreSQL will hand each of them.

```
                          APPLE EXPERT
                               │
                   ┌───────────┴───────────┐
            CUSTOMER EXPERIENCE          ADMIN
                   │                       │
       Google OAuth (primary),        email + password
       phone + SMS one-time code        (/admin/login)
        (kept, dormant until an             │
         SMS provider is bought)        user_roles
                   │                  owner/admin/staff
             Supabase Auth
                   │
        profiles.customer_type
           ┌───────┴────────┐
        retail          wholesale_vip
```

The rule everything else follows: **choosing an experience is not
authorisation.** Tapping "Wholesale Customer" on the entry screen says which
screens to show. Whether wholesale prices exist for you is decided by
`public.profiles.customer_type`, which the app cannot write — the column's
UPDATE privilege is revoked from `authenticated`, and only
`admin_set_customer_type()` can change it.

## The customer flow

| Step | Where |
|---|---|
| Entry screen — Retail or Wholesale (a UI preference only; retail browsing needs no sign-in) | `/welcome` |
| Continue with Google (primary), or phone number → code → verify (secondary, dormant until SMS is configured) | `/account/sign-in` |
| Google redirect lands here, waits for the session, then routes on | `/auth/callback` |
| First-time name (and optional email) — phone path only; Google already supplies a name | same screen, third step |
| Wholesale gateway: VIP, pending, rejected, or apply | `/wholesale` |

`/account/sign-up` is kept only as a redirect to `/account/sign-in`. With a
one-time code there is nothing to register: verifying a number that Apple Expert
has not seen before creates the account, and `public.handle_new_user()` creates
the matching `profiles` row with `customer_type` taking its `retail` default.

Nobody can sign up as a wholesale customer. There is no form field for it, no
request parameter for it, and the database would refuse it if there were.

## Google sign-in

The primary customer authentication method. Lives in one boundary module,
`src/lib/auth/google.ts` — the sign-in screen never calls
`supabase.auth.signInWithOAuth` directly, the same rule `otp.ts` follows for
phone. Like phone, it asks GoTrue's public `/auth/v1/settings` document
whether `external.google` is actually enabled before showing the button as
usable, so the screen never claims a capability the project doesn't have yet.

The app is a static export with no Node server, so there is no server-side
OAuth callback route. Two paths instead, both converging on the same
`/auth/callback` page:

- **Web**: a plain redirect to Google and back to `${origin}/auth/callback`.
  supabase-js's default `detectSessionInUrl` finishes the sign-in itself when
  that page's Supabase client is constructed — nothing in this app touches the
  token.
- **Capacitor/Android**: Google will not complete OAuth inside an embedded
  WebView, so `signInWithGoogle()` instead opens the system browser
  (`@capacitor/browser`, i.e. Chrome Custom Tabs) with `skipBrowserRedirect`
  and a custom-scheme `redirectTo` of `com.appleexpert.app://auth-callback`.
  `src/lib/auth/nativeOAuthListener.tsx`, mounted once in the shop layout,
  catches that scheme coming back via `@capacitor/app`'s `appUrlOpen` event,
  exchanges the code for a session itself, and routes to `/auth/callback` —
  from there it's identical to the web path. The scheme is registered as a
  second `<intent-filter>` on `MainActivity` in `AndroidManifest.xml`.

### Developer setup required

Google sign-in is wired into the app but returns `external.google: false`
today because no Google OAuth client has been configured. To turn it on:

1. **Google Cloud Console** → create an OAuth 2.0 Client ID (type: Web
   application). Add one Authorized redirect URI:
   `https://<your-project-ref>.supabase.co/auth/v1/callback` (found on
   Supabase's dashboard, Authentication → Providers → Google, once opened —
   it shows the exact URL to paste). No Android-specific client or SHA-1
   fingerprint is needed; this app always goes through the web/Custom Tabs
   flow, never Android's native Google Sign-In SDK.
2. **Supabase dashboard** → Authentication → Providers → Google → enable, and
   paste in the Client ID and Client Secret from step 1. Never put either of
   these in `.env.local`, a `NEXT_PUBLIC_*` variable, or anywhere in this repo
   — they belong only in the Supabase dashboard.
3. **Supabase dashboard** → Authentication → URL Configuration → Redirect
   URLs → add every URL the app can legitimately redirect back to:
   - `http://localhost:3000/auth/callback` (local dev)
   - `https://<your production web domain>/auth/callback`, if the storefront
     is also served on the web
   - `com.appleexpert.app://auth-callback` (the Android app)
4. Rebuild is **not** required to turn this on — like the phone form, the
   button reads the project's live capability at runtime. It is required after
   pulling this change for the first time, since the button and the Android
   deep-link are new code.

## SMS provider (kept, currently dormant)

Sending and verifying live in exactly one file: `src/lib/auth/otp.ts`. The UI
never calls Supabase Auth for OTP directly.

The screen asks the project what it can do rather than assuming, by reading
GoTrue's public `/auth/v1/settings` document:

- `external.phone === true` → the phone form works normally.
- otherwise → "SMS verification will be available soon", and the Send button is
  disabled.

**There is no fake mode.** No hardcoded code, no simulated delivery, no branch
that can report a verified number without GoTrue having verified it.

### Testing SMS against local Supabase

Production delivers codes through the Send SMS hook in
`supabase/functions/send-sms`, which sends through SMSlenz. Local Supabase runs the
same hook, configured in `supabase/config.toml` with a signing secret from
`supabase/.env`. That file is git-ignored and holds local values only.

1. Add `SMSLENZ_USER_ID`, `SMSLENZ_API_KEY` and `SMSLENZ_SENDER_ID` to `supabase/.env`.
   Without them the hook refuses and no code is sent.
2. Run `npx supabase start`, then
   `npx supabase functions serve --env-file supabase/.env --no-verify-jwt`.
   The runtime started by `supabase start` alone does not load these secrets.

Real codes cost SMS credit. Local codes last 6000 seconds because the CLI fixes that
value; production's is set in its dashboard. Never run `supabase config push` from
this config: it would send production's hook to `host.docker.internal`.

### When the SMS provider is purchased

1. In the Supabase dashboard: **Authentication → Providers → Phone** → enable,
   then enter the gateway's credentials (Twilio is the project's current
   default; Vonage, MessageBird and a generic HTTP hook are also supported).
2. Leave **Enable phone confirmations** on, and **phone autoconfirm off**.
3. Optionally set the SMS template and the OTP expiry.
4. Nothing to rebuild or redeploy — the installed APK reads the capability at
   runtime and the form goes live.
5. Turn Guest Test Mode off and cut a production build (below).

Two optional follow-ups, neither required for the flow to work:

- `public.handle_new_user()` copies `email` and `full_name` from the new auth
  user but not `phone`. The app fills `profiles.phone` itself straight after
  verification, so this is cosmetic; a one-line trigger change would do it
  inside PostgreSQL instead.
- Supabase's default SMS rate limits (per number and per hour) are worth
  reviewing against real traffic before launch.

## Guest Test Mode

A development feature for reviewing the retail and wholesale screens before the
SMS provider exists.

A guest is a flag in `sessionStorage` saying which screens to show. It is **not**
authentication and cannot become it:

- no Supabase session, no token, no JWT — real or fake;
- no account, no profile row, no VIP record;
- no `customer_type`. Prices are resolved by PostgreSQL from
  `private.current_customer_type()`, which reads `auth.uid()`. A guest has none,
  so every query returns public retail prices and row-level security physically
  withholds every `wholesale_vip` row;
- `sessionStorage`, not `localStorage`, so a test identity dies with the app
  session and never sits beside real preferences.

A TEST MODE banner is pinned to every screen while a guest is active, and the
wholesale portal renders as a clearly marked demo that shows the layout and
withholds the data.

### Enabling it (local testing)

```bash
# .env.local
NEXT_PUBLIC_ENABLE_GUEST_MODE=true
```

Then `npm run dev`, or `npm run build && npx cap sync android` for a test APK.
The entry screen gains a dashed **TESTING MODE** panel with "Continue as Retail
Guest" and "Continue as Wholesale Guest".

### Disabling it (production)

```bash
# .env.local — or simply omit the variable
NEXT_PUBLIC_ENABLE_GUEST_MODE=false
```

Rebuild. Two things then hold:

- **The entry is gone, not hidden.** The TESTING MODE panel on `/welcome` is
  gated on the literal `process.env.NEXT_PUBLIC_ENABLE_GUEST_MODE === 'true'`,
  which Next.js substitutes at build time, so the minifier deletes the block. A
  production bundle has no guest buttons in it to find.
- **Nothing can start or restore a guest session.** `startGuestSession()`
  returns immediately and `hydrate()` returns `null` without reading storage, so
  a stale flag left in a tester's browser — or a hand-edited `sessionStorage`
  entry — is ignored. The banner, the profile card and the wholesale demo panel
  all render from `useGuestMode()`, which can then only ever return `null`.

Verify a production build with:

```bash
grep -rl "Continue as Retail Guest" out/_next/static/chunks | wc -l   # expect 0
```

(The `apple-expert-guest-test-mode` storage key itself still appears in the
bundle — it lives in the guarded module, which is what does the ignoring.)

## What did not change

Administration is untouched: `/admin/login` and every `/admin/*` screen still
use email + password plus `user_roles` (`owner`/`admin`/`staff`). Customer tiers
(`retail`, `wholesale_vip`) and admin roles remain separate systems — a customer
tier grants no admin access and an admin role grants no pricing.

Adding Google sign-in did not touch the schema either, beyond one cosmetic
trigger change: `public.handle_new_user()` now also copies an avatar URL out
of Google's OAuth metadata into the already-existing `profiles.avatar_url`
column. Nothing in RLS, grants, `product_prices`, `price_tiers`, `orders`,
`user_roles`, or `admin_set_customer_type()` was altered — a Google session is
just another way to end up with a row in `auth.users`, and everything
downstream of that (the profile, the tier, the pricing) works exactly as it
did before.
