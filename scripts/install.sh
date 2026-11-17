#!/bin/bash

# shellcheck source=common.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/common.sh"
parse_args "$@"

#################
##### SETUP #####
#################

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

#################
##### UTILS #####
#################

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

#####################
###### FIREFOX ######
#####################

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

##############################
###### OPENTABLETDRIVER ######
##############################

# Only the files from the repo are replaced, the driver's logs and plugins stay
function otd_install {
	local file

	mkdir -p "${otd_dir}" || {
		echo "${FAIL} Couldn't create ${otd_dir}"
		return 1
	}
	for file in "${OTD_FILES[@]}"; do
		if [[ -e "${otd_dir}${file}" ]] &&
			! backup "${otd_dir}${file}" "${rice_dir}/OpenTabletDriver/${file}" "${backup_dir}OpenTabletDriver/"; then
			continue
		fi
		run_and_log "Installing ${rice_dir}/OpenTabletDriver/${file} to ${otd_dir}" cp "${rice_dir}/OpenTabletDriver/${file}" "${otd_dir}"
	done

	if command -v otd-daemon >/dev/null; then
		echo "${INFO} OpenTabletDriver only reads its settings when it starts: systemctl --user restart opentabletdriver.service"
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

##################
##### SCRIPT #####
##################

init
setup_backup_install
dirs_install
zsh_install
wallpaper_install
ff_install
otd_install
echo "${INFO} The new config folders have been moved to ${config_dir}"

clean_empty_backup ||
	echo "${INFO} The existing config folders found have been moved to ${backup_dir}"
