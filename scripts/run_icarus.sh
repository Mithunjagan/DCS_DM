#!/usr/bin/env sh
# Run the portable behavioral simulation without changing any HDL source.
# Usage: ./scripts/run_icarus.sh [delta] [samples]

set -eu

delta="${1:-128}"
samples="${2:-4096}"

case "$delta" in
  16|64|128|512) ;;
  *)
    echo "Error: delta must be one of 16, 64, 128, or 512." >&2
    exit 2
    ;;
esac

case "$samples" in
  ''|*[!0-9]*|0)
    echo "Error: samples must be a positive integer." >&2
    exit 2
    ;;
esac

command -v iverilog >/dev/null 2>&1 || {
  echo "Error: Icarus Verilog is not installed or not on PATH." >&2
  exit 127
}
command -v vvp >/dev/null 2>&1 || {
  echo "Error: the Icarus vvp runtime is not installed or not on PATH." >&2
  exit 127
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
output_dir="$repo_root/build/sim/delta-$delta"
mkdir -p "$output_dir"

cd "$output_dir"
iverilog -g2012 -s tb_dm "-Ptb_dm.DELTA=$delta" "-Ptb_dm.N=$samples" -o tb_dm.vvp \
  "$repo_root/DCS/sine_gen.v" \
  "$repo_root/DCS/delta_modulator.v" \
  "$repo_root/DCS/delta_demodulator.v" \
  "$repo_root/DCS/tb_dm.v"

vvp ./tb_dm.vvp

printf '\nSimulation complete: delta=%s, samples=%s\n' "$delta" "$samples"
printf 'CSV: %s/dm_out.csv\n' "$output_dir"
printf 'VCD: %s/tb_dm.vcd\n' "$output_dir"
