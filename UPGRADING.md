# Keeping Lava Chicken OS updated — a guide for parents

The box gets better over time. Bug fixes, new features, and the occasional "oh,
*that's* why Steam was cranky" all arrive as **updates** — free, forever, no
subscription. Two things make this painless:

1. **It updates itself,** quietly, in the background. Most of the time you don't
   have to do anything at all.
2. **When you *do* want to push an update** — or a kid asks "is there a new
   version?" — there's one friendly command. No `bootc`, no jargon.

And unlike the *install*, updating is the **safe** end of the pool: your kids'
files, games, saves, screenshots, and logins are never touched, and if an update
ever misbehaves you can roll straight back to the version that worked.

---

## The short version

On the box (or from your laptop over SSH), as an admin:

```bash
sudo lacos upgrade
```

That downloads the newest version and **stages** it. It does **not** restart the
computer — so it will never yank a kid out of a game. It takes effect the next
time the box restarts. That's the whole thing.

---

## How updates actually work (the reassuring bit)

Lava Chicken OS ships as a single **image** — think of it like a sealed cartridge
for the whole operating system. An update is just a newer cartridge: the box
downloads it and swaps over **on the next restart**.

The important part: **your stuff lives *outside* the cartridge.** Home folders,
Steam games and saves, art projects, Minecraft worlds, browser logins, the extra
apps you installed — all of it persists across every update. Updates only change
the system underneath.

And if a new cartridge ever turns out to be a dud, the old one is still sitting
right there to swap back to (see *If something looks off*, below).

---

## Doing it yourself — three commands

All of these need admin rights (`sudo`):

| Command | What it does |
|---|---|
| `sudo lacos upgrade` | Download the latest and **stage** it. **No reboot** — applies on the next restart. The best default: it won't interrupt anyone. |
| `sudo lacos upgrade --now` | Download **and restart now** to apply. Use it when nobody's on the box. |
| `sudo lacos upgrade --check` | Just look — is there a newer version? Changes nothing. |

If the box's background auto-updater happens to be busy when you run this,
`lacos upgrade` politely pauses it, does its thing, and puts it back — so you
never see a scary "System transaction in progress" error.

---

## When to restart

A staged update only becomes real on a restart. Pick a calm moment — **nobody
mid-game** — and either use the power menu → **Restart**, or run:

```bash
systemctl reboot
```

(Or skip the two-step and use `sudo lacos upgrade --now` next time, which stages
and restarts in one go.)

---

## Check it worked

After the box comes back up, confirm everything's healthy:

```bash
lacos doctor
```

All green and you're done. If it flags anything, `sudo lacos doctor --fix`
repairs the usual suspects and tells you what it's doing. The natural rhythm is
**upgrade → restart → `lacos doctor`.**

---

## If something looks off after an update

Rare — but the whole design assumes it *can* happen, which is why the previous
version is always kept. To go back to it:

```bash
sudo bootc rollback
systemctl reboot
```

You're back on the version that worked, with the kids' files untouched. Then run
`lacos doctor`, and if you can, [open an
issue](https://github.com/hartsock/lava-chicken-os/issues) — this is a hobby
project built in the open, and "this update broke X" is exactly the kind of
report that makes it better for the next family.

---

## The honest bit

This is free, given away for the joy of building it — no warranty, no support
contract. But updating is genuinely low-risk: it's reversible, it leaves your
family's stuff alone, and the scary part (the original install) is already behind
you. So update whenever you like, roll back if you ever must, and let `lacos
doctor` keep an eye on things.

🐔🌋
