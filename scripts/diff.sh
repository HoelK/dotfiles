#!/bin/bash

# Compares the configs in the repo with the ones installed on this machine.
# Read-only: it never changes a file.
# Exit code: 0 everything matches, 1 something differs or isn't installed, 2 error

# shellcheck source=common.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/common.sh"

full=false

while [[ $# -gt 0 ]]; do
	case "$1" in
		-f|--full)	full=true;	shift ;;
		-h|--help)
			echo "Usage: $0 [-f|--full]"
			echo "  Lists the configs that differ from the repo and the files that changed."
			echo "  -f, --full    also print the line by line diff (- repo, + installed)"
			exit 0 ;;
		-*)			echo "Unknown option: $1"	>&2;	exit 2 ;;
		*)			echo "Unknown argument $1"	>&2;	exit 2 ;;
	esac
done

#####################
##### VARIABLES #####
#####################

YELLOW=$'\e[0;33m'
SAME="${DEFAULT}[${GREEN} SAME ${DEFAULT}]"
DIFF="${DEFAULT}[${RED} DIFF ${DEFAULT}]"
MISSING="${DEFAULT}[${YELLOW} MISSING ${DEFAULT}]"

# Colored full diff only when printing to a terminal
if [[ -t 1 ]]; then
	diff_color=always
else
	diff_color=never
fi

differ=0	# configs that differ from the repo
missing=0	# configs not installed

#################
##### UTILS #####
#################

#$1 path to print, with ~ instead of the home folder
function pretty {
	echo "${1/#"${HOME}"/\~}"
}

#$1 folder in the repo
#$2 installed folder
# Prints each file that changed, relative to the folders
function list_changes {
	local file
	while IFS= read -r file; do
		if [[ ! -e "$2/${file}" ]]; then
			echo "only in repo     ${file}"
		elif [[ ! -e "$1/${file}" ]]; then
			echo "only installed   ${file}"
		elif ! cmp -s "$1/${file}" "$2/${file}"; then
			echo "modified         ${file}"
		fi
	done < <(find "$1" "$2" \( -type f -o -type l \) -printf '%P\n' | sort -u)
}

#$1 version in the repo
#$2 installed version
function check {
	local repo_path="$1" installed="$2"

	if [[ ! -e "${installed}" ]]; then
		echo "${MISSING} $(pretty "${installed}")"
		(( ++missing ))
		return
	fi
	if diff -rq "${repo_path}" "${installed}" >/dev/null 2>&1; then
		echo "${SAME} $(pretty "${installed}")"
		return
	fi

	echo "${DIFF} $(pretty "${installed}")"
	(( ++differ ))
	if [[ "${full}" == true ]]; then
		diff -ru --color="${diff_color}" "${repo_path}" "${installed}"
	elif [[ -d "${repo_path}" && -d "${installed}" ]]; then
		list_changes "${repo_path}" "${installed}" | sed 's/^/    /'
	fi
}

function check_firefox {
	local profile file

	if ! profile=$(ff_find_profile); then
		echo "${INFO} No Firefox profile found, Firefox skipped"
		return
	fi
	for file in "${FF_FILES[@]}"; do
		check "${rice_dir}/firefox/${file}" "${profile}/${file}"
	done
}

##################
##### SCRIPT #####
##################

for dir in "${DIRECTORIES[@]}"; do
	check "${rice_dir}/${dir}" "${config_dir}${dir}"
done
for file in "${FILES[@]}"; do
	check "${rice_dir}/${file}" "${HOME}/${file}"
done
check "${repo_dir}/wallpapers" "${share}wallpapers"
check_firefox

echo
if (( differ == 0 && missing == 0 )); then
	echo "${INFO} Everything installed matches the repo"
	exit 0
fi
echo "${INFO} ${differ} differ from the repo, ${missing} not installed"
exit 1
