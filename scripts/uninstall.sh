#!/bin/bash

# shellcheck source=common.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/common.sh"
parse_args "$@"

#################
##### SETUP #####
#################

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
	otd_uninstall	# same
}

#######################
##### DIRECTORIES #####
#######################

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

##############################
###### OPENTABLETDRIVER ######
##############################

function otd_uninstall {
	local file dir

	for file in "${OTD_FILES[@]}"; do
		if remove_if_rice "${otd_dir}${file}" "${rice_dir}/OpenTabletDriver/${file}" &&
			[[ -e "${backup_dir}OpenTabletDriver/${file}" ]]; then
			mkdir -p "${otd_dir}"
			run_and_log "Restoring ${backup_dir}OpenTabletDriver/${file} to ${otd_dir}" mv "${backup_dir}OpenTabletDriver/${file}" "${otd_dir}"
		fi
	done
	# Leave no empty folder behind: in the backup, and the one install created
	for dir in "${backup_dir}OpenTabletDriver" "${otd_dir}"; do
		if [[ -d "${dir}" ]]; then
			rmdir --ignore-fail-on-non-empty "${dir}"
		fi
	done
}

######################
##### WALLPAPERS #####
######################

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
setup_backup_uninstall
dirs_uninstall
zsh_uninstall
wallpaper_uninstall
ff_uninstall
otd_uninstall
echo "${INFO} The old config folders have been moved from ${backup_dir} to ${config_dir}"

clean_empty_backup ||
	echo "${INFO} Untouched config files found, backup still in ${backup_dir}"
