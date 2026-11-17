#!/bin/bash

# Checks that the programs and fonts the configs use are installed.
# Read-only: it never changes a file.
# Exit code: 0 everything needed is installed, 1 something is missing, 2 error

# shellcheck source=common.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/common.sh"

while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help)
			echo "Usage: $0"
			echo "  Checks that the programs and fonts the configs use are installed."
			exit 0 ;;
		-*)	echo "Unknown option: $1"	>&2;	exit 2 ;;
		*)	echo "Unknown argument $1"	>&2;	exit 2 ;;
	esac
done

#####################
##### VARIABLES #####
#####################

# Programs the configs need: "command|what uses it"
PROGRAMS=(
	"Hyprland|window manager"
	"start-hyprland|starts Hyprland at login (.zshrc)"
	"hyprpaper|wallpaper"
	"hyprlock|lock screen (SUPER+L, wlogout)"
	"waybar|status bar"
	"kitty|terminal (SUPER+Q)"
	"fuzzel|app launcher (SUPER+A)"
	"wlogout|logout menu (SUPER+Escape)"
	"firefox|browser (SUPER+W)"
	"hyprshot|screenshots (F10)"
	"wpctl|volume keys"
	"playerctl|media keys"
	"zsh|shell"
	"tmux|terminal multiplexer"
	"nvim|editor"
	"git|nvim plugins, git branch in the zsh prompt"
	"tree-sitter|nvim-treesitter parsers"
)

# Programs the rice works without: "command|what uses it"
OPTIONAL=(
	"hyprshutdown|SUPER+M, falls back to hyprctl"
	"keepassxc|password manager (SUPER+P)"
	"steam|SUPER+S"
	"otd-daemon|Wacom tablet in relative mode (OpenTabletDriver)"
)

# Fonts the configs use: "family|what uses it"
FONTS=(
	"Monocraft|fuzzel, hyprlock, waybar"
)

YELLOW=$'\e[0;33m'
OK="${DEFAULT}[${GREEN} OK ${DEFAULT}]"
MISSING="${DEFAULT}[${RED} MISSING ${DEFAULT}]"
OPTIONAL_MISSING="${DEFAULT}[${YELLOW} OPTIONAL ${DEFAULT}]"

missing=0			# needed and not installed
optional_missing=0	# optional and not installed

##################
#### PROGRAMS ####
##################

#$1 name of a "command|what uses it" array
#$2 true if the programs in it are optional
function check_programs {
	local -n programs="$1"
	local entry name

	for entry in "${programs[@]}"; do
		name="${entry%%|*}"
		if command -v "${name}" >/dev/null; then
			echo "${OK} ${name}"
		elif [[ "$2" == true ]]; then
			echo "${OPTIONAL_MISSING} ${name}: ${entry#*|}"
			(( ++optional_missing ))
		else
			echo "${MISSING} ${name}: ${entry#*|}"
			(( ++missing ))
		fi
	done
}

###############
#### FONTS ####
###############

function check_fonts {
	local entry name

	for entry in "${FONTS[@]}"; do
		name="${entry%%|*}"
		if [[ -n "$(fc-list "${name}" family)" ]]; then
			echo "${OK} font ${name}"
		else
			echo "${MISSING} font ${name}: ${entry#*|}"
			(( ++missing ))
		fi
	done
}

# Icons are private use characters (Nerd Font glyphs): each one used
# in the configs needs an installed font that has it, or it shows as a box.
function check_icons {
	# UTF-8 to find the icons, C collation so sort doesn't merge them as equal
	local -x LC_ALL=C.UTF-8
	local icon code file used_in count=0 icons_missing=0

	while IFS= read -r icon; do
		(( ++count ))
		code=$(printf '%X' "'${icon}")
		[[ -n "$(fc-list ":charset=${code}" family)" ]] && continue

		used_in=""
		while IFS= read -r file; do
			used_in+=" ${file#"${rice_dir}/"}"
		done < <(grep -rlF "${icon}" "${rice_dir}")
		echo "${MISSING} icon U+${code} (${icon}): no installed font has it, used in${used_in}"
		(( ++icons_missing ))
	done < <(grep -rhoIP '[\x{E000}-\x{F8FF}\x{F0000}-\x{10FFFD}]' "${rice_dir}" | sort -u)

	(( missing += icons_missing ))
	if (( count > 0 && icons_missing == 0 )); then
		echo "${OK} a font has each of the ${count} icons used in the configs"
	fi
}

##################
##### SCRIPT #####
##################

check_programs PROGRAMS false
check_programs OPTIONAL true

if command -v fc-list >/dev/null; then
	check_fonts
	check_icons
else
	echo "${MISSING} fc-list: fontconfig, needed to check the fonts"
	(( ++missing ))
fi

echo
if (( missing == 0 )); then
	echo "${INFO} Everything the rice needs is installed (${optional_missing} optional missing)"
	exit 0
fi
echo "${INFO} ${missing} missing, ${optional_missing} optional missing"
exit 1
