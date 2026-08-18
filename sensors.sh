#!/bin/bash
# Emits: "cpuTemp gpuTemp gpuFan cpuFan" — temps in °C, fans in RPM, "-" if unavailable.
# Default: one shot. With --loop <seconds>: stream one line per interval.
# One persistent process; QML reads lines from stdout.

INTERVAL=2
LOOP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --loop) LOOP=1 ;;
    --interval) INTERVAL="$2"; shift ;;
  esac
  shift
done

hwmon_by_name() {
  for d in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$d/name" 2>/dev/null)" = "$1" ] && { echo "$d"; return 0; }
  done
  return 1
}

# Super-IO chips (ITE/Nuvoton) expose board/CPU-header fans. Try known names,
# else any fan-bearing hwmon that isn't a GPU.
find_fan_dev() {
  for n in it8689 it8686 it8728 it8613 it8620 it87 nct6775 nct6776 nct6779 nct6791 nct6798 nct6683; do
    if d=$(hwmon_by_name "$n"); then { echo "$d"; return 0; }; fi
  done
  for d in /sys/class/hwmon/hwmon*; do
    name=$(cat "$d/name" 2>/dev/null)
    case "$name" in amdgpu|nouveau|nvidia) continue ;; esac
    if ls "$d"/fan*_input >/dev/null 2>&1; then { echo "$d"; return 0; }; fi
  done
  return 1
}

read_temp() { v=$(cat "$1" 2>/dev/null) && echo $((v / 1000)) || echo "-"; }
read_rpm() { v=$(cat "$1" 2>/dev/null) && echo "$v" || echo "-"; }

# Resolve devices once; hwmon layout doesn't change at runtime.
CPU_TEMP_DEV=""; GPU_DEV=""; FAN_DEV=""
[ -n "$(hwmon_by_name k10temp)" ] && CPU_TEMP_DEV=$(hwmon_by_name k10temp)
[ -z "$CPU_TEMP_DEV" ] && [ -n "$(hwmon_by_name coretemp)" ] && CPU_TEMP_DEV=$(hwmon_by_name coretemp)
[ -z "$CPU_TEMP_DEV" ] && [ -n "$(hwmon_by_name zenpower)" ] && CPU_TEMP_DEV=$(hwmon_by_name zenpower)
for d in /sys/class/hwmon/hwmon*; do
  name=$(cat "$d/name" 2>/dev/null)
  if [ "$name" = "amdgpu" ] || [ "$name" = "nouveau" ]; then
    if [ -f "$d/temp1_input" ]; then GPU_DEV="$d"; break; fi
  fi
done
[ -z "$GPU_DEV" ] && [ -n "$(hwmon_by_name nvidia)" ] && GPU_DEV=$(hwmon_by_name nvidia)
FAN_DEV=$(find_fan_dev)

# NVIDIA on some laptops (Optimus/PRIME without GFX hwmon) exposes no hwmon
# device; fall back to nvidia-smi which reads the driver directly.
NVIDIA_FALLBACK=""
if [ -z "$GPU_DEV" ] && command -v nvidia-smi >/dev/null 2>&1; then
  NVIDIA_FALLBACK="1"
fi

snapshot() {
  local cpu_temp="-" gpu_temp="-" gpu_fan="-" cpu_fan="-"

  [ -n "$CPU_TEMP_DEV" ] && cpu_temp=$(read_temp "$CPU_TEMP_DEV/temp1_input")

  if [ -n "$GPU_DEV" ]; then
    gpu_temp=$(read_temp "$GPU_DEV/temp1_input")
    [ -f "$GPU_DEV/fan1_input" ] && gpu_fan=$(read_rpm "$GPU_DEV/fan1_input")
  elif [ -n "$NVIDIA_FALLBACK" ]; then
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -dc '0-9')
    [ -n "$gpu_temp" ] || gpu_temp="-"
  fi

  # fan1 = CPU_FAN header on super-IO chips; else first non-GPU fan found.
  if [ -n "$FAN_DEV" ]; then
    local f
    f=$(ls "$FAN_DEV"/fan*_input 2>/dev/null | head -n1)
    [ -n "$f" ] && cpu_fan=$(read_rpm "$f")
  fi

  echo "$cpu_temp $gpu_temp $gpu_fan $cpu_fan"
}

snapshot
[ "$LOOP" = "1" ] || exit 0
while sleep "$INTERVAL"; do
  snapshot
done
