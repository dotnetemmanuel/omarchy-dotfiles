---
name: MPD VM share — Samba setup + recovery script 2026-05-21
description: Samba switchover for the mpd VM is done and at steady state. Runbook + idempotent recovery script exist. If anything breaks, run the script first before diagnosing from scratch.
type: project
originSessionId: e9eb0ef0-df24-4db3-9247-ddd4f98574df
---
The mpd VM's Linux↔Windows file share (`~/Source/GitHub/mpd` → `Z:\mpd\`) is on **Samba** (replaced virtiofs 2026-05-21). The setup involves a long list of non-obvious workarounds for Windows-vs-SMB binary execution issues. Full working state reached: VS Debug F5 launches both legacy `IdpSolutions.Mpd.WebPortal` (IIS Express @ 57897) + .NET 8 `Mpd.Web` (Kestrel @ 7247), browser login works, PWA serves at `/pwa` and dev hot-reload via `192.168.122.1:5173` works.

## Where things live

- **Full runbook**: `~/Documents/mpd-dev-flow-followups.md` — "Samba runbook" section. Read this first if the user asks anything about the dev flow.
- **Recovery script**: `~/Documents/mpd-samba-reapply.sh` — idempotent. Supports `--verify` (check, no changes) and `--unhide` (for committing real changes to a hidden file). Always treat this script as the source of truth; the runbook contains an inlined snapshot for reading only.
- **VM IP pin**: `192.168.122.76` is now a static libvirt DHCP entry (`virsh net-dumpxml default | grep host`). Will not drift across reboots.

## First-aid when "something broke"

**Step 1 — verify the local hacks are still in place:**
```bash
~/Documents/mpd-samba-reapply.sh --verify
```
Reports drift in any of the 6 assume-unchanged files + the `Mpd.Web/Directory.Build.props` local file. If it says "DRIFT DETECTED", run without `--verify` to fix everything.

**Step 2 — sanity-check the infrastructure:**
```bash
systemctl is-active smb                                # Samba service up
ls /home/emmanuel/mpd-share/mpd | head                 # bind mount working
virsh -c qemu:///system net-dumpxml default | grep host    # VM IP still pinned to 192.168.122.76
virsh -c qemu:///system domifaddr win11                     # VM actually has that IP
```

**Step 3 — known failure modes from the runbook's "Known gotchas" table:**

| Symptom | First-line fix |
|---|---|
| `Z:` not mapping in VM after reboot | The startup script `C:\Users\Emmanuel\bin\mount-mpd.cmd` should run from `shell:startup`; if not, manual `net use Z: \\192.168.122.1\mpd-share /persistent:no` |
| `Local device name is already in use` | `net use Z: /delete /y` then remap |
| `Access is denied` on some `.exe` or `.node` | Same Windows-binary-from-SMB block we've solved 5× — redirect that specific binary to local C:\ via env var |
| `Du kan inte logga in från denna ipp adress` | Mpd.Web's `applicationUrl` must use `*` not `0.0.0.0` (IPv6 matters — allowlist has `::1`). Re-apply script enforces this. |
| Build fails with `'Z:\mpd\ \packages\...'` (literal trailing space) | NuGet.targets patch reverted; re-run the recovery script |
| T4 errors corrupting `Database.cs` / `T4MVC.cs` | `<Generator>` re-appeared in csprojs after a pull; re-run the recovery script |
| Vite proxy returns 500 / login times out | Mpd.Web may have reverted to localhost binding, OR vite.config.ts proxy target reverted to localhost; re-run script |

## Things that diverged from the original 2026-05-20 plan (per the followups doc)

- Share renamed `[mpd]` → `[mpd-share]` and points at `~/mpd-share/` (a bind-mount wrapper) instead of directly `~/Source/GitHub/mpd`. Reason: MSBuild trailing-space SolutionDir bug breaks when .sln is at drive root.
- Disabled `RestoreOnBuild`-style legacy NuGet workflow in favor of pointing `NuGetExePath` at local `C:\tools\nuget.exe`.
- Mpd.Web build output redirected to `C:\dev\mpd-build\Mpd.Web\` via `Mpd.Web/Directory.Build.props` (gitignored locally via `.git/info/exclude`).
- VS Trust feature **disabled entirely** (uncheck "Require a trust decision"); it's a deprecated mechanism that doesn't honor mapped drives properly.

## Colleague impact

**Zero.** Every workaround is local-only — `assume-unchanged` flags, `.git/info/exclude`, or env vars + registry on the user's VM. The repo's tracked files are pristine. Colleagues with regular Windows dev boxes clone and F5 like always.

## How to use this memory in a future session

- If the user asks "samba isn't working" / "I can't log in" / "the build is broken" / similar — point at `~/Documents/mpd-samba-reapply.sh --verify` FIRST before diagnosing from scratch. Most likely cause is drift in one of the hidden files.
- If `--verify` is clean and there's still a problem, the "Known gotchas" table in the runbook (`~/Documents/mpd-dev-flow-followups.md`) maps symptoms to root causes.
- Don't re-derive any of the workarounds from scratch. Read the runbook first.
