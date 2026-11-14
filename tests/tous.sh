#!/bin/sh
# Lance tous les tests automatiques (Godot dans le PATH sous le nom « godot »).
# Usage : sh tests/tous.sh [motif]   (ex. sh tests/tous.sh telecom)
# Un test réussit s'il se termine avec le code 0 et affiche « TEST OK » ou
# « RÉSULTAT : OK ». Les erreurs de script (SCRIPT ERROR) sont signalées à part :
# elles ne font pas échouer la suite, mais doivent être corrigées.
cd "$(dirname "$0")/.." || exit 1
fail=0
total=0
ko=""
for t in tests/*${1:-}*_test.gd; do
	[ -f "$t" ] || continue
	total=$((total + 1))
	name=$(basename "$t")
	out=$(godot --headless --path . --script "res://$t" 2>&1)
	code=$?
	line=$(echo "$out" | grep -E "TEST (OK|ÉCHEC)|RÉSULTAT : (OK|ÉCHEC)" | tail -1)
	errs=$(echo "$out" | grep -c "SCRIPT ERROR")
	if [ "$code" -eq 0 ] && echo "$line" | grep -qE "TEST OK|RÉSULTAT : OK"; then
		echo "ok    $name"
	else
		[ -z "$line" ] && line="pas de résultat"
		echo "ÉCHEC $name (code $code) : $line"
		echo "$out" | grep -E "ÉCHEC|SCRIPT ERROR" | head -5 | sed 's/^/        /'
		fail=1
		ko="$ko $name"
	fi
	[ "$errs" -gt 0 ] && echo "      $name : $errs erreur(s) de script"
done
if [ $fail -eq 0 ]; then
	echo "SUITE OK ($total tests)"
else
	echo "SUITE EN ÉCHEC :$ko"
fi
exit $fail
