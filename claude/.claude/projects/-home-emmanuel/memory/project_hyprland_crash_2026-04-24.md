---
name: Hyprland crash 2026-04-24 — followup pending
description: Hyprland v0.54.3 SIGSEGV on XWayland ConfigureRequest crashed emmanuel's session; investigation done, fix plan pending user action later same day
type: project
originSessionId: 515eb5c9-4011-4e42-ab8d-99898b72144e
---
On 2026-04-24 at 09:54:48 CEST, Hyprland crashed (SIGSEGV), ejecting emmanuel from Omarchy. Investigation complete, fix deferred to after work that day.

**Why:** user asked to record state so we can pick up the remediation later in the day without re-running diagnostics.

**How to apply:** when emmanuel comes back asking about "the Hyprland crash" or "finishing that Hyprland thing", jump straight to the Remediation plan below. Re-verify versions before acting (Arch repo may have moved since, or upstream may have tagged v0.54.4+). Do not rebuild/install anything without confirming with emmanuel first.

### Diagnosis (frozen in time — verify before acting)
- Crash report: `~/.cache/hyprland/hyprlandCrashReport3118.txt` (Hyprland PID 3118, v0.54.3, commit `521ece46`)
- Coredumps from the event: Hyprland 3118, xdg-desktop-portal-hyprland 4909, hyprlock 170734, qemu-system-x86_64 (Android emulator) 146111, Hyprland 186792 on restart attempt — `coredumpctl list --since "2026-04-24"`
- Backtrace root: `std::__throw_bad_any_cast()` inside `Desktop::View::CWindow::onX11ConfigureRequest(CBox)` called from `CXWM::handleConfigureRequest`. Uncaught exception from an XWayland ConfigureRequest.
- Trigger context: log tail shows HDMI-A-1 "disconnected" and aquamarine re-scanning CRTCs. This was NOT a physical unplug — it was DPMS off from idle-lock. `~/.config/hypr/hypridle.conf` fires `hyprctl dispatch dpms off` at 5.5min idle, and `loginctl lock-session` at 5min. hyprlock (PID 170734) was active and SIGABRT'd the same second Hyprland did.
- **Trigger chain (confirmed by user + logs):** laptop idle → hypridle fires lock at 5min → hyprlock running → dpms off at 5.5min → monitor reconfigure event → standalone Android emulator window (qemu-system-x86_64, XWayland client) sends X11 ConfigureRequest → Hyprland's `Desktop::View::CWindow::onX11ConfigureRequest` hits `bad_any_cast` → uncaught → SEGV.
- User confirmed the Android emulator runs in its own standalone window (not embedded in Android Studio), which is consistent with it being a top-level XWayland client receiving the configure event.
- Reproducibility: **high.** Any idle-lock with the emulator running should repro this — it's not a one-off race with HDMI hot-plug as first hypothesized.

### Versions observed on 2026-04-24
- hyprland 0.54.3-2 (Arch repo, built 2026-03-31)
- Upstream latest release: v0.54.3 (2026-03-27) — **same version, no repo upgrade available**
- hyprgraphics 0.5.1-1 (crash report shows Hyprland built against 0.5.0 — minor skew, not believed to be the cause)
- aquamarine 0.10.0-4, hyprutils 0.12.0-1, hyprlang 0.6.8-3, hyprcursor 0.1.13-5, hyprlock 0.9.5-1, hypridle 0.1.7-8, xdg-desktop-portal-hyprland 1.3.11-4
- AUR: `hyprdynamicmonitors-bin 1.4.0-1` installed; `yay` available at /usr/bin/yay
- Post-v0.54.3 upstream master: one xwayland commit (#14135, selection transfer), not matching this backtrace

### Remediation plan (do later, with user present)
1. Re-check versions first: `pacman -Syu` dry-run and `gh release list --repo hyprwm/Hyprland --limit 3`. Prefer a stable repo bump over going git.
2. If no new release: offer `yay -S hyprland-git` to pick up post-release fixes on master. Confirm with emmanuel first — compositor swap, risk of breakage.
3. Before either path: note current versions and back up `~/.config/hypr/` so we can revert cleanly.
4. File an upstream issue at github.com/hyprwm/Hyprland with `~/.cache/hyprland/hyprlandCrashReport3118.txt` — backtrace is clean, trigger is reproducible (idle-lock + XWayland client), no matching issue found in search.
5. **Immediate workaround (most important, while fix pending):** don't leave the standalone Android emulator running when walking away from the laptop. Either pause/close the emulator, or temporarily bump idle timeouts in `~/.config/hypr/hypridle.conf`, or comment out the `dpms off` listener. Ask emmanuel which he prefers.
6. Separately: "pixman_region32_init_rect: Invalid rectangle passed" spam in the current session (PID 1982) is noisy but benign — don't conflate with the crash.

### Pending decision: hypridle timeout restructuring (also deferred)
emmanuel wants lock pushed to **45 min** from its current ~2.5 min. Undecided on how the other listeners should move. When picking this back up, present the four options below and get a pick before editing `~/.config/hypr/hypridle.conf`:

Current timings (note: comments in file are wrong — 151s is 2.5 min, not 5 min):
- screensaver (`omarchy-launch-screensaver` if hyprlock not already running): 150s / 2.5 min
- lock (`loginctl lock-session`): 151s / ~2.5 min + 1s
- kbd backlight off: 330s / 5.5 min
- dpms off (`hyprctl dispatch dpms off`): 330s / 5.5 min

Options to present:
- **A. Lock only** → lock 45min; screensaver/dpms unchanged. Odd UX (screen black at 5.5min but unlock prompt only at 45min).
- **B. Scale everything** → screensaver ~44min, lock 45min, dpms ~45.5min. Clean but wastes battery on unlocked bright screen.
- **C. Compromise** → dpms-off stays at 5.5min (battery), screensaver near lock, lock 45min. **Crash risk remains** — dpms-off is the implicated trigger.
- **D. C + move dpms-off to ~45.5min** → eliminates the known crash trigger entirely, at a battery cost.

Recommend **D** given the crash context, but user's call. Back up `hypridle.conf` before editing.
