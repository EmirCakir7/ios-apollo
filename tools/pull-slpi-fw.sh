#!/bin/bash
# The sensor DSP's (SLPI, "dsps") firmware for apollo's iOS root (xnu 0196, sweet_slpi.c), into research/apollo-slpi/.
#
# The firmware is Qualcomm's signed image on the phone's modem partition (Android mounts it at
# /vendor/firmware_mnt, files in image/): slpi.mdt and its segments slpi.b00 .. slpi.b20 (about 7.2 MiB).
# The copy of that partition tools/pull-wifi-fw.sh made (research/apollo-wifi/modem.img; backup/modem.img
# is the same) has them. Nothing on the phone is changed. Not in git (research/ is ignored).
#
# The kernel reads them from /usr/local/fw/ on the iOS root, like the audio DSP's (tools/pull-audio-fw.sh).
# Either way of getting them there (ONE boot with the firmware; after it they stay on the root):
#   python3 tools/mkadt.py ... --slpi-fw research/apollo-slpi            (mkadt-slpi.diff's option)
#   python3 tools/mkadt.py ... --files-from research/apollo-slpi/files-slpi.txt
# and then boot with apollo_slpi=1 (and apollo_slpi_mem=0x... if TrustZone refuses the memory).
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
img=${1:-$here/research/apollo-wifi/modem.img}
out=$here/research/apollo-slpi

[ -s "$img" ] || { echo "pull-slpi-fw.sh: no $img: run tools/pull-wifi-fw.sh first (the phone in recovery)" >&2; exit 1; }
mkdir -p "$out"
rm -f "$out"/slpi.mdt "$out"/slpi.b[0-9][0-9]
python3 -I "$here/tools/fatcopy.py" "$img" get image 'slpi.*' "$out" > /dev/null
[ -s "$out/slpi.mdt" ] || { echo "pull-slpi-fw.sh: no slpi.mdt in image/ of the modem partition" >&2; exit 1; }

list=$out/files-slpi.txt
{
	echo "# the sensor DSP's firmware for /usr/local/fw/ (tools/pull-slpi-fw.sh): for one boot"
	for f in "$out"/slpi.mdt "$out"/slpi.b[0-9][0-9]; do
		[ -e "$f" ] || continue
		echo "/usr/local/fw/$(basename "$f")=research/apollo-slpi/$(basename "$f") 0:0:0644"
	done
} > "$list"
count=$(grep -c '^/usr' "$list")
bytes=$(cat "$out"/slpi.mdt "$out"/slpi.b[0-9][0-9] 2>/dev/null | wc -c)
printf 'slpi.mdt and %u segments, %u bytes (%u MiB)\n' "$((count - 1))" "$bytes" "$((bytes / 1048576))"
echo "pull-slpi-fw.sh: with the audio DSP's firmware too (20 MiB) that is under mkadt.py's 48 MiB and 64 files for one boot"
echo "pull-slpi-fw.sh: research/apollo-slpi/files-slpi.txt lists them for mkadt.py --files-from; mkadt-slpi.diff adds --slpi-fw DIR"
