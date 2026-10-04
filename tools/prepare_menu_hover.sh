#!/usr/bin/env bash
# Quiet runtime derivative; Phoenix's canonical source remains untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
ffmpeg -hide_banner -y -i audio/sfx/ui/hover.wav \
  -af 'atrim=start=0:end=0.18,asetpts=PTS-STARTPTS,lowpass=f=1800:p=2,afade=t=in:st=0:d=0.012,afade=t=out:st=0.09:d=0.09,volume=-15dB' \
  -ar 44100 -c:a pcm_s16le -map_metadata -1 audio/sfx/ui/hover_soft.wav
