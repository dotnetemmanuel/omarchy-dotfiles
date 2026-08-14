#!/usr/bin/env bash
# One JSON object of processor, memory, graphics and thermal readings for the
# sysmon bar plugin. Everything comes from sysfs, so this needs no privileges.
set -uo pipefail

state="${XDG_RUNTIME_DIR:-/tmp}/omarchy-sysmon.jiffies"

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

# Whole degrees from a millidegree sysfs file, or "null" when unreadable.
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

# Busy percentage over the gap since the previous call, so no sampling sleep.
cpu_percent() {
  local total idle prev_total=0 prev_idle=0 dt di
  read -r total idle < <(awk '/^cpu /{ i=$5+$6; t=0; for (n=2; n<=NF; n++) t+=$n; print t, i; exit }' /proc/stat)
  [[ -n ${total:-} ]] || { printf 'null'; return; }

  [[ -r $state ]] && read -r prev_total prev_idle <"$state" 2>/dev/null
  printf '%s %s\n' "$total" "$idle" >"$state" 2>/dev/null || true

  dt=$((total - prev_total))
  di=$((idle - prev_idle))
  if ((prev_total > 0 && dt > 0 && di >= 0)); then
    local pct=$(((100 * (dt - di) + dt / 2) / dt))
    ((pct < 0)) && pct=0
    ((pct > 100)) && pct=100
    printf '%d' "$pct"
  else
    printf 'null'
  fi
}

cpu="$(cpu_percent)"

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

printf '{'
printf '"cpu":%s,' "$cpu"
printf '"memUsedKb":%s,"memTotalKb":%s,' "$mem_used_kb" "$mem_total_kb"
printf '"cpuTemp":%s,"gpuTemp":%s,"diskTemp":%s,"fanRpm":%s,' "$cpu_temp" "$gpu_temp" "$disk_temp" "$fan"
printf '"gpuBusy":%s,"vramUsed":%s,"vramTotal":%s' "$gpu_busy" "$vram_used" "$vram_total"
printf '}\n'
