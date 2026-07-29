---
name: home-sso-setup
description: Set up "Home SSO" so LaCOS kids log into home apps (Gitea, dashboards, anything on your home domain) without a second login. Walks a homelab owner through the SERVER side (an Authentik identity server + one OIDC client + per-kid accounts + auto-provisioning their apps) and the BOX side (`lacos setup` Home SSO + per-kid enrollment). For people who want the same seamless setup in their own home.
argument-hint: "[--check | --box | --server]"
---

# /home-sso-setup — one home login for the kids

You are helping a homelab owner (often a parent who is technical-ish, not a
full-time sysadmin — see INSTALL.md's audience) make home websites "just work"
for their kids: the kid signs in once to the *home* identity, and Gitea / other
`*.home.<domain>` apps stop asking for a separate login.

Be procedure-first and concrete. This spans **two machines**: the home server
(where the identity provider lives) and the LaCOS box. Keep the kid's desktop
login **local and passwordless** — never make booting or gaming depend on the
network.

## The shape of it (explain this first)

```
kid's LOCAL desktop login (passwordless, offline-safe)
        └─ opens gitea.home.<domain> ─► home identity session already live ─► signed in, no prompt
```

Two ingredients make it seamless:
1. The box **trusts the home CA** (no TLS warnings).
2. The kid has **one home identity** (in the identity server) and signs in
   **once**; the browser session persists, so every home app rides it.

## Prerequisites (check with `--check`)

- A **home identity server** that speaks OIDC. This guide assumes
  [Authentik](https://goauthentik.io) (what the reference home.lab uses); any
  OIDC IdP works with the same shapes.
- A **home DNS / LAN domain** so `authentik.home.<domain>`, `gitea.home.<domain>`
  resolve. (The `lacos setup` "Home DNS" step sets the box side of this.)
- **TLS on the home apps** from a home CA you can hand to the box.
- At least one home app to prove it against — **Gitea** is the reference.

If they have none of this yet, point them at their IdP's install docs first;
this skill assumes the IdP is already up.

## Server side (`--server`)

Do these on the home server / identity provider. Commands shown for Authentik
via `ak shell`; adapt names for another IdP.

1. **One OIDC client for the desktop.** A *public* client named e.g.
   "LaCOS Desktop", grant includes device-code, scopes
   `openid email profile offline_access`. Note its **client_id** — the box asks
   for it. (Device-code powers optional CLI tokens; the browser-login path works
   without it.)
2. **Per-kid accounts.** Create one identity per kid. **Match the kid's LaCOS
   local username** (e.g. box user `josiah` → IdP user `josiah`) so LaCOS user =
   IdP user = app username line up. Put them in a `family` group.
3. **Auto-provision the apps.** Configure each home app to create accounts from
   an SSO login so you don't hand-make an account in every app. For **Gitea**:
   ```
   [oauth2_client]
   ENABLE_AUTO_REGISTRATION = true
   ACCOUNT_LINKING = auto        # link to an existing account by email
   USERNAME = nickname           # from the IdP preferred_username claim
   [service]
   DISABLE_REGISTRATION = true             # no local self-signup
   ALLOW_ONLY_EXTERNAL_REGISTRATION = true # ...but SSO logins may create accounts
   ```
4. **Match the redirect URI exactly.** The #1 failure is a `redirect_uri`
   mismatch: the app must send the *same* hostname the IdP has registered
   (e.g. Gitea's `ROOT_URL` domain must equal the IdP's registered callback
   host — `.lab` vs `.lan` will bite you). Verify:
   ```
   curl -sk -D- "https://gitea.home.<domain>/user/oauth2/<SourceName>" | grep -i location
   ```
   The `redirect_uri=` in that Location must match what the IdP has on file.
5. **Password recovery.** Decide up front: admin-reset (always works), email
   reset links (needs SMTP — e.g. a Gmail app password relay), and/or linking a
   Google login per kid (password-free recovery).

## Box side (`--box`)

On the LaCOS box, as the admin:

```
lacos setup            # answer "Home DNS" first, then the "Home SSO" step
```

The Home SSO step asks for the **Authentik URL**, the **client_id** from step 1,
and a **home CA** (path/URL, or blank to auto-detect from TLS). It trusts the CA
(system + Flatpak browsers), installs a per-login refresh service, and offers to
**enroll each kid**. Per kid, anytime:

```
lacos-sso login      # "Sign in to Home" — sign in once; home apps stay signed in
lacos-sso status     # is this user enrolled / signed in?
lacos-sso enroll     # optional: cache a CLI token (needs IdP device-code flow)
```

## Verify (the acceptance test)

On the box, as a kid: open `https://gitea.home.<domain>`. Expected: **signed in
as themselves, no prompt**, and their app account was created on first visit.
Offline, the desktop + local games are unaffected.

## Common failures

- **`redirect_uri` error** → hostname mismatch (see server step 4). Fix the
  app's base URL or the IdP's registered callback so they're identical.
- **TLS warnings in the browser** → the home CA isn't trusted on the box; re-run
  the Home SSO step with the correct CA path/URL. Flatpak browsers also need the
  host CA store shared in (the provision step does this).
- **Kid gets "registration disabled"** → the app isn't set to auto-provision
  from SSO (server step 3).
- **Re-prompted often** → raise the IdP session / "stay signed in" lifetime.
