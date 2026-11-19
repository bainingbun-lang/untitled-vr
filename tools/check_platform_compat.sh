#!/usr/bin/env bash
set -u

PROJECT="${1:-$HOME/UNTITLED}"

shopt -s globstar nullglob

RE_ABS='/(sdcard|data/data|home|usr|tmp|mnt|etc|root|storage/emulated|proc|sys)(/|$)'
RE_PROC='OS[.](execute|shell_open|create_process)[(]'
RE_CDB='ClassDB[.]instantiate[(]'
RE_CDB_GUARD='ClassDB[.]class_exists'
RE_SO='[.]so([^[:alnum:]]|$)'
RE_FALLBACK='(fallback|class_exists|has_method|has_feature)'
RE_CASE='(res|user)://[^"[:space:]]*[A-Z]'
RE_PATH='(res|user)://[^"[:space:]]+'

declare -A CASE_SEEN=()
RESULTS=()
SCANNED=0
GRAVE_COUNT=0
ADVISORY_COUNT=0

report() {
	local severity="$1" code="$2" file="$3" line="$4" message="$5"
	if [ "$severity" = "GRAVE" ]; then
		GRAVE_COUNT=$((GRAVE_COUNT + 1))
	else
		ADVISORY_COUNT=$((ADVISORY_COUNT + 1))
	fi
	RESULTS+=("$(printf '%s:%s: %s [%s] %s' "$file" "$line" "$severity" "$code" "$message")")
}

has_path_backslash() {
	local line="$1" trimmed="${1%"${1##*[![:space:]]}"}" i next
	[[ "$trimmed" == *\\ ]] && return 1
	case "$line" in
		*contains\(*|*replace\(*|*_PATTERN*) return 1 ;;
	esac
	for ((i = 0; i < ${#line} - 1; i++)); do
		[ "${line:i:1}" = '\' ] || continue
		next="${line:i+1:1}"
		case "$next" in
			t|n|r|'"'|"'"|'\'|s|d) continue ;;
		esac
		return 0
	done
	return 1
}

check_paths() {
	local file="$1" line_no="$2" rest="$3" path key previous match
	while [[ "$rest" =~ $RE_PATH ]]; do
		match="${BASH_REMATCH[0]}"
		path="$match"
		key="${path,,}"
		previous="${CASE_SEEN[$key]:-}"
		if [ -n "$previous" ] && [ "$previous" != "$path" ]; then
			report ADVISORY CASO_INCONSISTENTE "$file" "$line_no" \
				"misma ruta con distinta capitalizacion: $previous / $path"
		else
			CASE_SEEN[$key]="$path"
		fi
		rest="${rest#*"$match"}"
	done
}

check_line() {
	local file="$1" line_no="$2" line="$3" has_guard="$4" has_fallback="$5"

	if [[ "$line" =~ $RE_ABS ]]; then
		report GRAVE RUTA_ABSOLUTA "$file" "$line_no" \
			"ruta absoluta de Linux/Android; solo se permiten res:// y user://"
	fi

	if [[ "$line" =~ $RE_PROC ]]; then
		report GRAVE PROCESO_EXTERNO "$file" "$line_no" \
			"llamada a proceso externo; no disponible en Android/VR"
	fi

	if [[ "$line" =~ $RE_CDB ]] && [ "$has_guard" -eq 0 ]; then
		report GRAVE CLASSDB_SIN_GUARDA "$file" "$line_no" \
			"ClassDB.instantiate sin comprobacion previa de ClassDB.class_exists"
	fi

	if [[ "$line" =~ $RE_SO ]] && [ "$has_fallback" -eq 0 ]; then
		report GRAVE SO_SIN_FALLBACK "$file" "$line_no" \
			"dependencia de biblioteca .so sin alternativa cuando la extension no existe"
	fi

	if [[ "$line" =~ $RE_CASE ]]; then
		report ADVISORY RUTA_MAYUSCULAS "$file" "$line_no" \
			"ruta con mayusculas; revisar capitalizacion exacta en Windows"
	fi

	if has_path_backslash "$line"; then
		report ADVISORY BACKSLASH "$file" "$line_no" \
			"posible separador backslash en una ruta; no portable a Android"
	fi

	check_paths "$file" "$line_no" "$line"
}

scan_file() {
	local file="$1"
	local relative="${file#$PROJECT/}"
	local content line_no=0 line has_guard=0 has_fallback=0

	content=$(<"$file")
	if [[ "$content" =~ $RE_CDB_GUARD ]]; then
		has_guard=1
	fi
	if [[ "$content" =~ $RE_FALLBACK ]]; then
		has_fallback=1
	fi

	while IFS= read -r line || [ -n "$line" ]; do
		line_no=$((line_no + 1))
		check_line "$relative" "$line_no" "$line" "$has_guard" "$has_fallback"
	done <<< "$content"
}

for root in "$PROJECT/core" "$PROJECT/tests"; do
	[ -d "$root" ] || continue
	for file in "$root"/**/*.gd; do
		[ -f "$file" ] || continue
		SCANNED=$((SCANNED + 1))
		scan_file "$file"
	done
done

printf 'PLATFORM_COMPAT_CHECK\n'
printf 'proyecto: %s\n' "$PROJECT"
printf 'archivos .gd analizados: %d (core/ y tests/)\n' "$SCANNED"
printf 'hallazgos: %d (graves: %d, informativos: %d)\n' \
	"$((GRAVE_COUNT + ADVISORY_COUNT))" "$GRAVE_COUNT" "$ADVISORY_COUNT"
printf -- '--- hallazgos (archivo:linea) ---\n'
for result in "${RESULTS[@]}"; do
	printf '%s\n' "$result"
done
printf -- '--- fin ---\n'
if [ "$GRAVE_COUNT" -eq 0 ]; then
	printf 'RESULTADO: LIMPIO (sin hallazgos graves)\n'
	exit 0
fi
printf 'RESULTADO: NO APTO (hay hallazgos graves)\n'
exit 1
