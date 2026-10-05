#!/usr/bin/env bash
# User-approved edit: keep the first 25 s and the entire Cordys title ending.
# Usage: bash tools/prepare_prologue_cinematic.sh /absolute/Octopus_demonV3.mp4
# Original source and the deferred PR #96 full-video derivative stay untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
source_movie="${1:?Supply the canonical Octopus_demonV3.mp4 source}"
expected_sha="138c4d3d4b720febae992e6cd8e8c30260513caaeb8e359a0240a8b69665226b"
actual_sha="$(shasum -a 256 "$source_movie" | awk '{print $1}')"
encoder="${FFMPEG:-ffmpeg}"
# macOS's minimal Homebrew ffmpeg does not include Theora; use installed full.
if [ -z "${FFMPEG:-}" ] && [ -x /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg ]; then
  encoder=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
fi
if [ "$actual_sha" != "$expected_sha" ]; then
  echo "Source differs from the reviewed V3; re-inspect cut boundaries first." >&2
  exit 1
fi
# Frame 1630 is the first C in Cordys, immediately after the monologue.
# Concatenate before encoding: one runtime stream, no seeks during gameplay.
"$encoder" -hide_banner -loglevel warning -y -i "$source_movie" \
  -filter_complex '[0:v]split=2[iv][ev];[iv]trim=start_frame=0:end_frame=750,setpts=PTS-STARTPTS[i];[ev]trim=start_frame=1630,setpts=PTS-STARTPTS[e];[0:a]asplit=2[ia][ea];[ia]atrim=start=0:end=25,asetpts=PTS-STARTPTS[ai];[ea]atrim=start=54.333333333333,asetpts=PTS-STARTPTS[ae];[i][ai][e][ae]concat=n=2:v=1:a=1[v][a];[v]scale=1280:720,setsar=1[scaled]' \
  -map '[scaled]' -map '[a]' -c:v libtheora -q:v 7 -pix_fmt yuv420p \
  -c:a libvorbis -q:a 5 -ar 48000 -ac 2 \
  media/cutscenes/octopus_prologue.ogv
