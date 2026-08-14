#!/usr/bin/env bash
# One JSON object of processor, memory, graphics and thermal readings for the
# sysmon bar plugin. Everything comes from sysfs, so this needs no privileges.
#
# Load is a delta against the previous call, so the first call after a reboot
# reports null and every call after it is a true average over the poll gap.
set -uo pipefail

runtime="${XDG_RUNTIME_DIR:-/tmp}"
cpu_state="$runtime/omarchy-sysmon.cpu"
proc_state="$runtime/omarchy-sysmon.procs"
cache="$runtime/omarchy-sysmon.cache"
lock="$runtime/omarchy-sysmon.lock"
cache_seconds=2

# One bar instance exists per monitor, so several copies of this script run at
# the same moment against the same counters. Unserialised they read each other
# half-written state and split one poll gap between them, which shows up as
# malformed output and shares collapsing to nothing. Take the lock, and let a
# fresh sample serve every caller.
exec 9>"$lock" 2>/dev/null && flock 9 2>/dev/null || true

if [[ -s $cache ]]; then
  cached_at="$(stat -c %Y "$cache" 2>/dev/null || echo 0)"
  age=$(($(date +%s) - cached_at))
  if ((age >= 0 && age < cache_seconds)); then
    cat "$cache"
    exit 0
  fi
fi

hwmon_named() {
  local want="$1" dir
  for dir in /sys/class/hwmon/hwmon*; do
    [[ -r "$dir/name" ]] || continue
    if [[ "$(<"$dir/name")" == "$want" ]]; then
      printf '%s' "$dir"
      return 0
    fi
  done
  return 1
}

degrees() {
  local raw
  raw="$(cat "$1" 2>/dev/null)" || { printf 'null'; return; }
  [[ $raw =~ ^-?[0-9]+$ ]] || { printf 'null'; return; }
  printf '%d' $(((raw + 500) / 1000))
}

number_or_null() {
  local raw
  raw="$(cat "$1" 2>/dev/null)" || { printf 'null'; return; }
  [[ $raw =~ ^[0-9]+$ ]] || { printf 'null'; return; }
  printf '%s' "$raw"
}

# Emits "overall <pct|null>", "cores <csv>" and "total <jiffies>", and rewrites
# the state file with this call's counters.
read_cpu() {
  awk -v prev="$cpu_state" -v out="$cpu_state.$$" '
    BEGIN {
      while ((getline line < prev) > 0) {
        split(line, f, " ")
        seen[f[1]] = 1; ptotal[f[1]] = f[2]; pidle[f[1]] = f[3]
      }
      close(prev)
    }

    /^cpu/ {
      key = $1
      idle = $5 + $6
      total = 0
      for (i = 2; i <= NF; i++) total += $i
      print key, total, idle > out

      pct = -1
      if (key in seen) {
        dt = total - ptotal[key]
        di = idle - pidle[key]
        if (di < 0) di = 0
        if (dt > 0) {
          pct = int((100 * (dt - di) + dt / 2) / dt)
          if (pct < 0) pct = 0
          if (pct > 100) pct = 100
        }
      }

      if (key == "cpu") {
        overall = pct
        absolute = total
      } else {
        n = substr(key, 4) + 0
        core[n] = pct
        if (n + 1 > ncore) ncore = n + 1
      }
    }

    END {
      close(out)
      printf "overall %s\n", (overall >= 0 ? overall : "null")
      csv = ""
      for (i = 0; i < ncore; i++) {
        v = (i in core && core[i] >= 0) ? core[i] : "null"
        csv = csv (i ? "," : "") v
      }
      printf "cores %s\n", csv
      printf "total %d\n", absolute + 0
    }
  ' /proc/stat
}

# Heaviest processes, scaled so 100% is one core fully used, the same convention
# top and btop print. A process absent from the previous sample was created
# inside this window, so all of its time counts; without that a freshly spawned
# hog is invisible exactly when it matters.
#
# The window is measured from the processor counter stored alongside the last
# process sample rather than assumed to be one poll, so a gap of any length
# still divides by the time that actually elapsed.
read_processes() {
  local now_total="$1" ncpu="$2"
  ((ncpu > 0)) || return 0

  printf '%s\n' /proc/[0-9]*/stat |
  awk -v prev="$proc_state" -v out="$proc_state.$$" -v now_total="$now_total" -v ncpu="$ncpu" '
    BEGIN {
      while ((getline line < prev) > 0) {
        split(line, f, " ")
        if (f[1] == "#TOTAL") { prev_total = f[2]; continue }
        seen[f[1]] = 1; pjif[f[1]] = f[2]
        had_state = 1
      }
      close(prev)
      delta = now_total - prev_total
      if (prev_total <= 0 || delta <= 0) had_state = 0
      print "#TOTAL", now_total > out
    }

    # Each file is read here rather than passed as an argument: a process
    # exiting mid-scan is routine, and awk treats an unopenable argument as
    # fatal, which truncated the state file and dropped the whole ranking.
    {
      path = $0
      line = ""
      if ((getline line < path) <= 0) { close(path); next }
      close(path)

      open_at = index(line, "(")
      close_at = 0
      for (i = length(line); i > 0; i--) if (substr(line, i, 1) == ")") { close_at = i; break }
      if (open_at < 2 || close_at <= open_at) next

      pid = substr(line, 1, open_at - 2)
      name = substr(line, open_at + 1, close_at - open_at - 1)
      split(substr(line, close_at + 2), f, " ")

      # Skip kernel threads (migration, kworker, ksoftirqd): the kernel keeping
      # house is not something to put in front of someone asking what is busy.
      if (int(f[7] / 2097152) % 2) next

      jif = f[12] + f[13]
      print pid, jif > out
      if (!had_state) next

      used = (pid in seen) ? jif - pjif[pid] : jif
      if (used <= 0) next
      busy[pid] = used
      label[pid] = name
    }

    END {
      close(out)
      n = 0
      for (pid in busy) { order[++n] = pid }
      for (i = 1; i < n; i++)
        for (j = i + 1; j <= n; j++)
          if (busy[order[j]] > busy[order[i]]) { t = order[i]; order[i] = order[j]; order[j] = t }

      for (i = 1; i <= n && i <= 5; i++) {
        pct = 100 * ncpu * busy[order[i]] / delta
        gsub(/[\\"\t]/, "", label[order[i]])
        printf "%s\t%s\t%.1f\n", order[i], label[order[i]], pct
      }
    }
  '
}

cpu=null
cores=""
cpu_total=0
while read -r key value; do
  case $key in
    overall) cpu="$value" ;;
    cores) cores="$value" ;;
    total) cpu_total="$value" ;;
  esac
done < <(read_cpu)
mv -f "$cpu_state.$$" "$cpu_state" 2>/dev/null || true

# Never emit a bare key: a truncated reading has to degrade to null, not to
# output the panel cannot parse at all.
[[ $cpu =~ ^(null|[0-9]+)$ ]] || cpu=null
[[ $cores =~ ^(null|[0-9]+)(,(null|[0-9]+))*$ ]] || cores=""

ncpu=0
[[ -n $cores ]] && ncpu="$(awk -F, '{print NF}' <<<"$cores")"

# Several copies of the same program are common (one editor or agent per
# project), so name alone does not say which is which. The working directory
# does, when it is one worth naming.
where_of() {
  local cwd="" base
  cwd="$(readlink "/proc/$1/cwd" 2>/dev/null)" || return 0
  [[ -n $cwd && $cwd != "/" && $cwd != "$HOME" ]] || return 0
  base="${cwd##*/}"
  base="${base//[\\\"]/}"
  printf '%s' "$base"
}

ranking="$(read_processes "$cpu_total" "$ncpu")"
mv -f "$proc_state.$$" "$proc_state" 2>/dev/null || true

procs='['
first=1
while IFS=$'\t' read -r pid name pct; do
  [[ -n ${pct:-} ]] || continue
  ((first)) || procs+=','
  first=0
  procs+="{\"name\":\"$name\",\"where\":\"$(where_of "$pid")\",\"pct\":$pct}"
done <<<"$ranking"
procs+=']'

read -r mem_total_kb mem_avail_kb < <(
  awk '/^MemTotal:/ { t=$2 } /^MemAvailable:/ { a=$2 } END { print t+0, a+0 }' /proc/meminfo
)
mem_used_kb=$((mem_total_kb - mem_avail_kb))

cpu_temp=null
if dir="$(hwmon_named k10temp)"; then cpu_temp="$(degrees "$dir/temp1_input")"; fi

gpu_temp=null
if dir="$(hwmon_named amdgpu)"; then gpu_temp="$(degrees "$dir/temp1_input")"; fi

disk_temp=null
if dir="$(hwmon_named nvme)"; then disk_temp="$(degrees "$dir/temp1_input")"; fi

fan=null
if dir="$(hwmon_named thinkpad)"; then fan="$(number_or_null "$dir/fan1_input")"; fi

gpu_busy=null
vram_used=null
vram_total=null
for busy in /sys/class/drm/card*/device/gpu_busy_percent; do
  [[ -r $busy ]] || continue
  gpu_busy="$(number_or_null "$busy")"
  card="$(dirname "$busy")"
  vram_used="$(number_or_null "$card/mem_info_vram_used")"
  vram_total="$(number_or_null "$card/mem_info_vram_total")"
  break
done

{
  printf '{'
  printf '"cpu":%s,"cores":[%s],' "$cpu" "$cores"
  printf '"memUsedKb":%s,"memTotalKb":%s,' "$mem_used_kb" "$mem_total_kb"
  printf '"cpuTemp":%s,"gpuTemp":%s,"diskTemp":%s,"fanRpm":%s,' "$cpu_temp" "$gpu_temp" "$disk_temp" "$fan"
  printf '"gpuBusy":%s,"vramUsed":%s,"vramTotal":%s,' "$gpu_busy" "$vram_used" "$vram_total"
  printf '"processes":%s' "$procs"
  printf '}\n'
} >"$cache.$$"

mv -f "$cache.$$" "$cache" 2>/dev/null || true
cat "$cache"
