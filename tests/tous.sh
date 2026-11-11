#!/bin/sh
# Lance tous les tests automatiques (Godot dans le PATH sous le nom « godot »).
# Usage : sh tests/tous.sh
cd "$(dirname "$0")/.." || exit 1
fail=0
for t in tests/*_test.gd; do
	out=$(godot --headless --path . --script "res://$t" 2>&1)
	line=$(echo "$out" | grep -E "TEST (OK|ÉCHEC)" | tail -1)
	[ -z "$line" ] && line="$(basename "$t") : pas de résultat"
	echo "$line"
	echo "$line" | grep -q "TEST OK" || fail=1
done
exit $fail
