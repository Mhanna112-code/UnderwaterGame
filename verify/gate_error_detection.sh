#!/usr/bin/env bash
# Verifies the actual shared gate wrapper rejects an engine ERROR even when
# its child exits0, and still accepts an ordinary healthy child. No Godot
# fixture is needed: this tests the log/exit IO boundary, not game behavior.
set -euo pipefail
cd "$(dirname "$0")/.."
for probe in --probe-engine-error --probe-script-error; do
	status=0
	bash verify/gates.sh "$probe" >/dev/null 2>&1 || status=$?
	if [ "$status" -ne 1 ]; then
		printf 'FINDING runner %s returned %s, expected1\n' "$probe" "$status"
		exit 1
	fi
done
bash verify/gates.sh --probe-healthy >/dev/null 2>&1
printf 'GATE ERROR DETECTION: clean (engine/script witnesses rejected, healthy child accepted)\n'
