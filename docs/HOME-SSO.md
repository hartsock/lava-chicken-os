# Home SSO — one login for home apps

*Optional. Only for boxes that live on a home network with an [Authentik](https://goauthentik.io)
identity server (like the home.lab setup). If that's not you, skip this — LaCOS
works fine without it.*

## What it does (in plain English)

Kids sign into the LaCOS desktop the normal way — a **local, passwordless
account** (so games work even with no internet). Home SSO adds a small bridge so
that home websites — your **Gitea**, dashboards, whatever runs on `*.home.lab` —
**don't ask them to log in again**. They open the site and they're already in,
as themselves.

The magic is two pieces working together:

1. **Trust the home CA** — so `https://*.home.lab` shows no scary certificate
   warnings.
2. **One home sign-in that sticks** — the kid signs into the home identity
   server (Authentik) **once**; after that, every home app rides that session
   with no prompt, until it eventually expires (weeks).

Nothing about this makes the box depend on the network to *boot* or *play* — if
you're offline, the desktop and local games are unaffected; only the home
websites (which are unreachable off-network anyway) wait.

## Setting it up

Run the wizard and answer the **Home SSO** step (it appears once you've told the
wizard you have a home DNS / LAN domain):

```
lacos setup
```

You'll be asked for:

- **Authentik base URL** — e.g. `https://authentik.home.lab`
- **Home SSO client ID** — the *LaCOS Desktop* application in Authentik
  (an admin creates this once; it's a public, device-code OIDC client with the
  `offline_access` scope)
- **Home CA** — a path or URL to your home root CA cert (or leave blank to
  auto-detect it from the server's TLS chain)

The wizard trusts the CA, installs a per-login refresh service, and offers to
**enroll each kid** right then.

## Enrolling a kid

Enrollment is a **one-time device-code login** per kid:

```
lacos-sso enroll
```

It prints a short code and opens the browser; the kid (or you) signs into their
home account once and types the code. Their token is saved in the login
**keyring** (never written to disk in the clear). After that:

- `lacos-sso login` — the **"Sign in to Home"** desktop app; opens the home
  portal so the browser session is established/renewed.
- `lacos-sso status` — is this user enrolled?
- `lacos-sso refresh` — runs automatically at login (via `lacos-sso.service`)
  to keep the session warm; a no-op when offline.
- `lacos-sso logout` — clear this user's cached token.

## How it fits together

```
kid's LOCAL desktop login (passwordless, offline-safe)
        │
        ├─ lacos-sso.service  ──►  refresh home token (best-effort, silent)
        │
        └─ opens gitea.home.lab ──►  Authentik session already live ──►  signed in, no prompt
```

- **Identity:** each kid is a per-kid Authentik user (native account now; a
  Google login can be linked later). Their LaCOS username, Authentik username,
  and Gitea username line up.
- **Accounts appear on first visit:** Gitea is set to auto-provision from an
  Authentik login, so a kid's first visit creates their Gitea account with no
  manual step.

## Admin notes

- The Authentik side is a **public OIDC client** named *LaCOS Desktop* with the
  device-code grant and scopes `openid email profile offline_access`, plus a
  per-kid user and a `family` group. No policy binding = any family member may
  use it.
- Browser SSO relies on a **persistent browser profile** + Authentik's session
  lifetime. Set the Authentik session/"stay signed in" duration generously so
  kids aren't re-prompted often.
- Password resets: see your Authentik admin (a parent can reset a kid's
  password or, once email is configured, send a reset link).

_Tracking: [#69](https://github.com/hartsock/lava-chicken-os/issues/69)._
