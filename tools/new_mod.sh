#!/data/data/com.termux/files/usr/bin/bash
set -eu

TEMPLATE_DIR="/data/data/com.termux/files/home/UNTITLED/mods/_template"
MODS_DIR="/data/data/com.termux/files/home/UNTITLED/mods"

usage() {
	cat <<EOF
Uso: new_mod.sh <mod_id> [author]

Crea un nuevo mod a partir de la plantilla en mods/_template

Argumentos:
  mod_id   ID del mod en formato autor.nombre (ej: miproyecto.miarma)
  author   Autor opcional (por defecto: untitled)

Ejemplos:
  new_mod.sh miarma
  new_mod.sh miarma miusuario
EOF
	exit 1
}

validate_mod_id() {
	local mod_id="$1"
	if [[ ! "$mod_id" =~ ^[a-z0-9-]+\.[a-z0-9-]+$ ]]; then
		echo "ERROR: mod_id debe tener formato 'autor.nombre' (solo minusculas, numeros, guiones)" >&2
		exit 1
	fi
}

main() {
	if [ $# -lt 1 ] || [ $# -gt 2 ]; then
		usage
	fi

	local mod_id="$1"
	local author="${2:-untitled}"
	local full_id="${author}.${mod_id}"

	validate_mod_id "$full_id"

	local target_dir="${MODS_DIR}/${full_id}"

	if [ -e "$target_dir" ]; then
		echo "ERROR: El mod '$full_id' ya existe en $target_dir" >&2
		exit 1
	fi

	echo "Creando mod: $full_id"
	echo "Directorio: $target_dir"

	mkdir -p "$target_dir"

	# Copiar plantilla base
	cp "$TEMPLATE_DIR/mod.json" "$target_dir/mod.json"

	# Actualizar mod.json con el ID correcto
	sed -i "s/untitled.template-mod/$full_id/g" "$target_dir/mod.json"
	sed -i "s/Template mod/$mod_id/g" "$target_dir/mod.json"

	# Copiar contenido de armas
	mkdir -p "$target_dir/content"
	cp "$TEMPLATE_DIR/content/weapons.json" "$target_dir/content/weapons.json"
	sed -i "s/untitled.template-mod/$full_id/g" "$target_dir/content/weapons.json"
	sed -i "s/template_weapon/${mod_id}_weapon/g" "$target_dir/content/weapons.json"
	sed -i "s/Arma de plantilla/${mod_id^} Weapon/g" "$target_dir/content/weapons.json"

	# Copiar contenido de NPCs
	cp "$TEMPLATE_DIR/content/npcs.json" "$target_dir/content/npcs.json"
	sed -i "s/untitled.template-mod/$full_id/g" "$target_dir/content/npcs.json"
	sed -i "s/template_npc/${mod_id}_npc/g" "$target_dir/content/npcs.json"
	sed -i "s/NPC de plantilla/${mod_id^} NPC/g" "$target_dir/content/npcs.json"

	# Copiar contenido de sonidos
	cp "$TEMPLATE_DIR/content/sounds.json" "$target_dir/content/sounds.json"
	sed -i "s/untitled.template-mod/$full_id/g" "$target_dir/content/sounds.json"
	sed -i "s/template_weapon/${mod_id}_weapon/g" "$target_dir/content/sounds.json"
	sed -i "s/template_npc/${mod_id}_npc/g" "$target_dir/content/sounds.json"

	# Copiar plantilla de hook
	mkdir -p "$target_dir/${mod_id}_hook"
	cp "$TEMPLATE_DIR/template_hook/main.gd" "$target_dir/${mod_id}_hook/main.gd"
	sed -i "s/template_hook/${mod_id}_hook/g" "$target_dir/${mod_id}_hook/main.gd"

	# Crear mod.json con hooks
	cp "$TEMPLATE_DIR/mod_with_hooks.json" "$target_dir/mod_with_hooks.json.example"
	sed -i "s/untitled.template-hook/$full_id/g" "$target_dir/mod_with_hooks.json.example"
	sed -i "s/template_hook/${mod_id}_hook/g" "$target_dir/mod_with_hooks.json.example"
	sed -i "s/Template mod with hooks/$mod_id Hook Example/g" "$target_dir/mod_with_hooks.json.example"

	echo "Mod creado exitosamente en: $target_dir"
	echo ""
	echo "Estructura:"
	find "$target_dir" -type f | sort
	echo ""
	echo "Para validar el mod:"
	echo "  grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tools/validate_mod.gd -- res://mods/$full_id"
	echo ""
	echo "Para construir el mod (generar PCK):"
	echo "  ~/tools/build_example_mod.sh  (adaptar para tu mod)"
}

main "$@"