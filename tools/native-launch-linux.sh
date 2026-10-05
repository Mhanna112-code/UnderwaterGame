#!/bin/sh
cd "$(dirname "$0")" || exit 1
exec ./UnderwaterGame.x86_64 --rendering-method gl_compatibility "$@"
