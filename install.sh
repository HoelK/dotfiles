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
repo_dir="$(dirname "$(realpath "$0")")"
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
		mkdir "${backup_dir}" || {
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
function backup {
	if diff -rq "${repo_dir}/$(basename "${1}")" "${1}" >/dev/null 2>&1; then
		rm -rf "${1:?}"
		echo "${INFO} ${1} is already the rice, not backed up"
		return 0
	fi

	if mv "${1}" "${backup_dir}"; then
		echo "${SUCCESS} Backed up ${1}"
		return 0
	else
		echo "${FAIL} Couldn't backup ${1}"
		return 1
	fi
}

function remove_if_rice {
	if [[ -e "${1}" ]] && ! diff -rq "${repo_dir}/$(basename "${1}")" "${1}" >/dev/null 2>&1; then
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
	remove_if_rice "${share}wallpapers"
}

#######################
##### DIRECTORIES #####
#######################

function dirs_install {
	local dir
	for dir in "${DIRECTORIES[@]}"; do
		local path_under_conf="${config_dir}${dir}"
		local path_under_repo="${repo_dir}/${dir}"

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
	local new_zsh="${repo_dir}/.zshrc"
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


######################
##### WALLPAPERS #####
######################

function wallpaper_install {
	if [[ -d "${share}wallpapers" ]] &&
		! backup "${share}wallpapers"; then
		return 1
	fi

	run_and_log "Installing ${repo_dir}/wallpapers to ${share}" cp -r "${repo_dir}/wallpapers" "${share}"
}

function wallpaper_uninstall {
	if remove_if_rice "${share}wallpapers" &&
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
	echo "${INFO} The old config folders have been moved from ${backup_dir} to ${config_dir}"
else
	setup_backup_install
	dirs_install
	zsh_install
	wallpaper_install
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

