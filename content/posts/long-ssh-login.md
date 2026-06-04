---
title: "Long SSH Login: pam_systemd 25s Delay"
date: 2026-06-04T04:06:39+00:00
tags: [ "ssh", "linux", "pam", "systemd", "troubleshooting" ]
categories: [ "guide" ]
---

# Long SSH Login

## What is PAM

Pluggable Authentication Modules (PAM) is a middleware layer between applications (`sshd`, `su`, `login`, `sudo`) and authentication logic. Programs link against `libpam.so` and delegate authentication to it. Every login goes through a stack of modules defined in `/etc/pam.d/`.

## Why Login is Slow

PAM runs modules sequentially on every login. If one module hangs, your login waits. Common suspects include `pam_motd.so`, `pam_lastlog.so`, and `pam_env.so`. In constrained deployments, the main offender is often:

## `pam_systemd.so` — the 25 second culprit

If SSH login hangs for exactly **25 seconds**, `pam_systemd.so` is likely the cause.

It registers a `systemd-logind` session over D-Bus on every login. In containers, LXC, or minimal environments, `logind` is often not running while the D-Bus socket still exists. The module sends a request and waits for a reply that never arrives, then times out at the default D-Bus method call timeout (**25 seconds**).

## Fix

### Option 1 — Start logind

Use this if you need session tracking:

```bash
systemctl enable --now systemd-logind
```

### Option 2 — Remove it from PAM (recommended for containers)

```bash
# /etc/pam.d/sshd
# session optional pam_systemd.so
```

Since it is `optional`, authentication still works, but the timeout delay is removed.

## Not Just SSH

Check whether `pam_systemd.so` appears in `/etc/pam.d/common-session`. On Debian/Ubuntu-based systems this file is often included broadly, so many PAM-aware prompts can incur the same delay (`su`, `sudo`, TTY login, etc.).

```bash
grep -r "pam_systemd" /etc/pam.d/
```
