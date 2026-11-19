#!/usr/bin/env bash
set -u

GODOT="$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64"
PROJECT="$HOME/UNTITLED"
status=0

if ! bash "$PROJECT/tools/build_example_mod.sh"; then
	printf 'FAIL build_example_mod.sh\n'
	exit 1
fi

for path in "$PROJECT"/tests/test_*.gd; do
	name=$(basename "$path")
	output=$(grun "$GODOT" --headless --path "$PROJECT" --script "res://tests/$name" 2>&1)
	code=$?
	filtered=$(printf '%s\n' "$output" | grep -v -i 'libfontconfig' || true)
	if [ "$code" -eq 0 ]; then
		printf 'PASS %s\n' "$name"
	else
		printf 'FAIL %s\n' "$name"
		printf '%s\n' "$filtered"
		status=1
	fi
done

exit "$status"
