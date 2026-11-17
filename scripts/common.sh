# Shared by install.sh and uninstall.sh, not meant to be run on its own.

#####################
##### VARIABLES #####
#####################

# Debug variables
DEFAULT=$'\033[0m'
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
INFO="${DEFAULT}[ INFO ]"
FAIL="${DEFAULT}[${RED} FAIL ${DEFAULT}]"
SUCCESS="${DEFAULT}[${GREEN} SUCCESS ${DEFAULT}]"

# Config dirs to apply
DIRECTORIES=(
	"hypr"
	"tmux"
	"nvim"
	"kitty"
	"waybar"
	"wlogout"
	"fuzzel"
)

# Files to apply
FILES=(
	".zshrc"
)

# Files to apply in the Firefox profile
FF_FILES=(
	"user.js"
	"chrome"
)

# Config paths
: ${HOME:?HOME env required}
config_dir="${HOME}/.config/"
backup_dir="${config_dir}config-back/"
repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
rice_dir="${repo_dir}/config"
share="${HOME}/.local/share/"

#############################
##### Environment setup #####
#############################

#$@	the script arguments, only -h/--help is accepted
function parse_args {
	while [[ $# -gt 0 ]]; do
	  case "$1" in
	    -h|--help)	echo "Usage: $0";				exit 0 ;;
	    -*)			echo "Unknown option: $1"	>&2;	exit 1 ;;
		*)			echo "Unknown argument $1"	>&2;	exit 1 ;;
	  esac
	done
}

function init {
	# Creating share
	if ! [[ -d "${share}" ]]; then
		mkdir -p "${share}" || {
			echo "${FAIL} Couldn't create ${share}."
			echo "Aborting..."
			exit 1
		}
	fi

	# Creating backup
	if ! [[ -d "${backup_dir}" ]]; then
		mkdir -p "${backup_dir}" || {
			echo "${FAIL} Couldn't create ${backup_dir}."
			echo "Aborting..."
			exit 1
		}
	fi
}

#################
##### UTILS #####
#################

#$1	logs
#$2	cmd
#	The rests are cmd arguments
function run_and_log {
	local log=${1}; shift
	if "$@"; then
		echo "${SUCCESS} ${log}"
		return 0
	else
		echo "${FAIL} ${log}"
		return 1
	fi
}

# Removes the backup folder if it's empty, fails if something is left in it
function clean_empty_backup {
	if [[ -n "$(find "${backup_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
		return 1
	fi
	echo "${INFO} Backup directory is empty, cleaning up..."
	rm -rf "${backup_dir}"
}

#####################
###### FIREFOX ######
#####################

# Prints the folder of the profile Firefox opens, fails if there is none.
# Firefox keeps using ~/.mozilla if it exists, new installs use ~/.config/mozilla.
function ff_find_profile {
	local dir ff_dir="" profile

	for dir in "${HOME}/.mozilla/firefox" "${XDG_CONFIG_HOME:-${HOME}/.config}/mozilla/firefox"; do
		if [[ -f "${dir}/profiles.ini" ]]; then
			ff_dir="${dir}"
			break
		fi
	done
	[[ -n "${ff_dir}" ]] || return 1

	# The [Install...] section names the profile Firefox opens
	# (not Profile0, not the one with Default=1)
	profile=$(awk -F= '
		/^\[Install/			{ inst=1; next }
		/^\[/					{ inst=0 }
		inst && $1=="Default"	{ print $2; exit }
	' "${ff_dir}/profiles.ini")
	[[ -n "${profile}" ]] || return 1

	# Path is relative to the Firefox dir, unless it's absolute (IsRelative=0)
	[[ "${profile}" == /* ]] || profile="${ff_dir}/${profile}"
	[[ -d "${profile}" ]] || return 1
	echo "${profile}"
}
