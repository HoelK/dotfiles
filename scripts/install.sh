#!/bin/bash

uninstalling=false

while [[ $# -gt 0 ]]; do
  case "$1" in
	--uninstall)	uninstalling=true;					shift ;;
    -h|--help)		echo "Usage: $0 [--uninstall]";		exit 0 ;;
    -*)				echo "Unknown option: $1"	>&2;	exit 1 ;;
	*)				echo "Unknown argument $1"	>&2;	exit 1 ;;
  esac
done

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
)

# Files to apply
FILES=(
	".zshrc"
)

# Config paths
: ${HOME:?HOME env required}
config_dir="${HOME}/.config/"
backup_dir="${config_dir}config-back/"
repo_dir="$(dirname "$(dirname "$(realpath "$0")")")"
rice_dir="${repo_dir}/config"
share="${HOME}/.local/share/"

#############################
##### Environment setup #####
#############################

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


function setup_backup_install {
	if ! [ -n "$(find "${backup_dir}" -mindepth 1 -maxdepth 1 -type d -print -quit)" ]; then
		last=1
	else
		last=$(( $(ls -d "${backup_dir}"*/ | xargs -n1 basename | sort -n | tail -1) + 1 ))
	fi

	backup_dir="${backup_dir}${last}/"
	mkdir "${backup_dir}" || {
		echo "${FAIL} Couldn't create ${backup_dir}."
		echo "Aborting..."
		exit 1
	}

	echo "${INFO} Config path setup to ${config_dir}"
	echo "${INFO} Backup path setup to ${backup_dir}"
}

function setup_backup_uninstall {
	if ! [ -n "$(find "${backup_dir}" -mindepth 1 -maxdepth 1 -type d -print -quit)" ]; then
		echo "$INFO No config backed up"
		remove_all
		exit 0
	fi
	last=$(( $(ls -d "${backup_dir}"*/ | xargs -n1 basename | sort -n | tail -1) ))
	backup_dir="${backup_dir}${last}/"

	echo "${INFO} Config path setup to ${config_dir}"
	echo "${INFO} Backup path setup to ${backup_dir}"
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


#$1 path of dir to backup
#$2 its version in the repo	(default: same name in config/)
#$3 where to back it up		(default: the backup folder)
function backup {
	local repo_path="${2:-${rice_dir}/$(basename "${1}")}"
	local dest="${3:-${backup_dir}}"

	if diff -rq "${repo_path}" "${1}" >/dev/null 2>&1; then
		rm -rf "${1:?}"
		echo "${INFO} ${1} is already the rice, not backed up"
		return 0
	fi

	if mkdir -p "${dest}" && mv "${1}" "${dest}"; then
		echo "${SUCCESS} Backed up ${1}"
		return 0
	else
		echo "${FAIL} Couldn't backup ${1}"
		return 1
	fi
}

#$1 path to remove
#$2 its version in the repo	(default: same name in config/)
function remove_if_rice {
	local repo_path="${2:-${rice_dir}/$(basename "${1}")}"

	if [[ -e "${1}" ]] && ! diff -rq "${repo_path}" "${1}" >/dev/null 2>&1; then
		echo "${INFO} ${1} is not the rice, left untouched"
		return 1
	fi
	rm -rf "${1:?}"
}

function remove_all {
	local dir
	for dir in "${DIRECTORIES[@]}"; do
		remove_if_rice "${config_dir}${dir}"
	done
	remove_if_rice "${HOME}/.zshrc"
	remove_if_rice "${share}wallpapers" "${repo_dir}/wallpapers"
	ff_uninstall	# no backup folder here, so it only removes
}

#######################
##### DIRECTORIES #####
#######################

function dirs_install {
	local dir
	for dir in "${DIRECTORIES[@]}"; do
		local path_under_conf="${config_dir}${dir}"
		local path_under_repo="${rice_dir}/${dir}"

		if [[ -d "${path_under_conf}" ]] &&
			! backup "${path_under_conf}"; then
			continue
		fi
		run_and_log "Installing ${path_under_repo} to ${config_dir}" cp -r "${path_under_repo}" "${config_dir}."
	done
}

function dirs_uninstall {
	local dir
	for dir in "${DIRECTORIES[@]}"; do
		local path_under_conf="${config_dir}${dir}"
		local path_under_back="${backup_dir}${dir}"

		if remove_if_rice "${path_under_conf:?}" &&
			[[ -d "${path_under_back}" ]]; then
			run_and_log "Restoring ${path_under_back} to ${path_under_conf}" mv "${path_under_back}" "${path_under_conf}"
		fi 
	done
}


##################
##### FILES ######
##################

function zsh_install {
	local new_zsh="${rice_dir}/.zshrc"
	local old_zsh="${HOME}/.zshrc"

	if [[ -f "${old_zsh}" ]] && ! backup "${old_zsh}"; then
		return 1
	fi
	run_and_log "Installing ${new_zsh} to ${old_zsh}" cp "${new_zsh}" "${old_zsh}"
}

function zsh_uninstall {
	local new_zsh="${backup_dir}/.zshrc"
	local old_zsh="${HOME}/.zshrc"

	if remove_if_rice "${old_zsh}" && [[ -f ${new_zsh} ]]; then
		run_and_log "Restoring ${new_zsh} to ${old_zsh}" mv "${new_zsh}" "${old_zsh}"
	fi
}


#####################
###### FIREFOX ######
#####################

FF_FILES=(
	"user.js"
	"chrome"
)

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

function ff_install {
	local profile file

	if ! profile=$(ff_find_profile); then
		echo "${INFO} No Firefox profile found (launch Firefox once and re-run), Firefox skipped"
		return 0
	fi
	echo "${INFO} Firefox profile found at ${profile}"

	for file in "${FF_FILES[@]}"; do
		if [[ -e "${profile}/${file}" ]] &&
			! backup "${profile}/${file}" "${rice_dir}/firefox/${file}" "${backup_dir}firefox/"; then
			continue
		fi
		run_and_log "Installing ${rice_dir}/firefox/${file} to ${profile}" cp -r "${rice_dir}/firefox/${file}" "${profile}/"
	done
}

function ff_uninstall {
	local profile file

	profile=$(ff_find_profile) || return 0

	for file in "${FF_FILES[@]}"; do
		if remove_if_rice "${profile}/${file}" "${rice_dir}/firefox/${file}" &&
			[[ -e "${backup_dir}firefox/${file}" ]]; then
			run_and_log "Restoring ${backup_dir}firefox/${file} to ${profile}" mv "${backup_dir}firefox/${file}" "${profile}/"
		fi
	done
	# Leave no empty folder behind, so the backup can be cleaned up
	if [[ -d "${backup_dir}firefox" ]]; then
		rmdir --ignore-fail-on-non-empty "${backup_dir}firefox"
	fi
}

######################
##### WALLPAPERS #####
######################

function wallpaper_install {
	if [[ -d "${share}wallpapers" ]] &&
		! backup "${share}wallpapers" "${repo_dir}/wallpapers"; then
		return 1
	fi

	run_and_log "Installing ${repo_dir}/wallpapers to ${share}" cp -r "${repo_dir}/wallpapers" "${share}"
}

function wallpaper_uninstall {
	if remove_if_rice "${share}wallpapers" "${repo_dir}/wallpapers" &&
		[[ -d "${backup_dir}wallpapers" ]]; then
		run_and_log "Restoring ${backup_dir}/wallpapers to ${share}" mv "${backup_dir}/wallpapers" "${share}"
	fi
}

##################
##### SCRIPT #####
##################

init

if [[ ${uninstalling} == true ]]; then
	setup_backup_uninstall
	dirs_uninstall
	zsh_uninstall
	wallpaper_uninstall
	ff_uninstall
	echo "${INFO} The old config folders have been moved from ${backup_dir} to ${config_dir}"
else
	setup_backup_install
	dirs_install
	zsh_install
	wallpaper_install
	ff_install
	echo "${INFO} The new config folders have been moved to ${config_dir}"

fi


####################
##### LEFTOVER #####
####################

if ! [ -n "$(find "${backup_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
	echo "${INFO} Backup directory is empty, cleaning up..."
	rm -rf "${backup_dir}"
elif [[ "${uninstalling}" == false ]]; then
	echo "${INFO} The existing config folders found have been moved to ${backup_dir}"
elif [[ "${uninstalling}" == true ]]; then
    echo "${INFO} Untouched config files found, backup still in ${backup_dir}"
fi

